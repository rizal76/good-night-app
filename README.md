# Good Night Application

## Task Requirements

We would like you to implement a "good night" application to let users track when they go to bed and when they wake up.

We require some RESTful APIs to achieve the following:

1.  **Clock In operation**: Record sleep tracking and return all clocked-in times, ordered by created time.
2.  **Follow/Unfollow users**: Users can follow and unfollow other users.
3.  **View following users' sleep records**: See the sleep records of all following users from the previous week, sorted by sleep duration.

Example response format for requirement #3:

```json
{
  "record 1": "from user A",
  "record 2": "from user B",
  "record 3": "from user A"
}

```

**Requirements:**

-   Implement models, database migrations, schema, and JSON APIs
-   Write comprehensive tests for all APIs
-   Handle growing user base with high data volumes and concurrent requests efficiently
-   Users have only two fields: `id` and `name`
-   No user registration API needed
-   Use any gems as needed

----------

## Product Assumptions

### Clock In Feature

I assume that to record sleep, the user simply clocks in once to start tracking, and clocks in again to end the sleep session. Therefore, I use the same API endpoint for both actions.

To prevent race conditions (e.g., accidental double clock-ins within a short time), I've added validation requiring a minimum sleep duration of X seconds before allowing clock-out. This threshold is configurable via `Rails.configuration.sleep.min_duration_seconds` 

### Sleep Record Data Retention

Since the requirement specifies displaying only the last 7 days of data, I've made the following assumptions for handling large-scale data:

-   **Compress data older than 7 days** to save storage space
-   **Drop data after 30 days** to maintain database performance

These retention policies are implemented using TimescaleDB's built-in features and help manage storage costs at scale.

----------

## Technical Architecture

### Database Design

#### Schema Overview

### Users Table

| Column      | Type     | Constraints         |
|-------------|----------|---------------------|
| id          | bigint   | PRIMARY KEY         |
| name        | string   | NOT NULL            |
| created_at  | datetime | NOT NULL            |
| updated_at  | datetime | NOT NULL            |

### Sleep Records Table (Hypertable)

| Column         | Type        | Constraints                              |
|----------------|-------------|------------------------------------------|
| id             | bigserial   | PRIMARY KEY (composite with clock_in_time) |
| user_id        | bigint      | NOT NULL, FOREIGN KEY → users.id         |
| clock_in_time  | timestamptz | NOT NULL, PRIMARY KEY (composite with id) |
| clock_out_time | timestamptz | NULL                                     |
| duration       | integer     | NULL (seconds)                           |
| created_at     | datetime    | NOT NULL                                 |
| updated_at     | datetime    | NOT NULL                                 |

### Follows Table

| Column       | Type     | Constraints                           |
|--------------|----------|---------------------------------------|
| id           | bigint   | PRIMARY KEY                           |
| follower_id  | bigint   | NOT NULL, FOREIGN KEY → users.id      |
| followed_id  | bigint   | NOT NULL, FOREIGN KEY → users.id      |
| created_at   | datetime | NOT NULL                              |
| updated_at   | datetime | NOT NULL                              |



#### Why TimescaleDB Hypertable?

TimescaleDB is chosen for the `sleep_records` table because:

1.  **Time-series optimization**: Sleep records are inherently time-series data, queried primarily by time ranges (e.g., "last 7 days")
2.  **Automatic partitioning**: Data is automatically chunked by `clock_in_time` with 1-day intervals, improving query performance
3.  **Built-in compression**: Automatically compresses data older than 7 days, reducing storage costs and boost performance
4.  **Data retention policies**: Automatically drops data older than 30 days, maintaining database performance
5.  **Efficient time-range queries**: Optimized for queries filtering by date ranges, which is our primary access pattern

Configuration:

```ruby
acts_as_hypertable(
  time_column: "clock_in_time",
  chunk_time_interval: "1 day",
  compress_orderby: "clock_in_time DESC",
  compress_after: "7 days",
  drop_after: "30 days"
)

```

### Index Strategy

#### Sleep Records Indexes

**Optimized Composite Index:**

```sql
CREATE INDEX idx_sleep_records_optimized
ON sleep_records (user_id, clock_in_time, duration DESC)
WHERE clock_out_time IS NOT NULL;

```

This index follows the ERS (Equality-Range-Sort) rule:

-   **Equality**: `user_id` for filtering by specific users
-   **Range**: `clock_in_time` for time-range queries (last 7 days)
-   **Sort**: `duration DESC` for ordering by sleep duration

**Why this index?**

-   Covers the most common query pattern: fetch sleep records for specific users within a time range, sorted by duration
-   Partial index (`WHERE clock_out_time IS NOT NULL`) reduces index size by excluding incomplete sessions
-   Composite index is more efficient than separate single-column indexes

**Additional Index:**

```sql
CREATE INDEX index_sleep_records_on_user_id_and_created_at
ON sleep_records (user_id, created_at DESC);

```


-   Used for paginated user sleep history (response in the API clock in)

#### Follows Table Indexes

```sql
CREATE INDEX index_follows_on_follower_id ON follows (follower_id);
CREATE INDEX index_follows_on_followed_id ON follows (followed_id);
CREATE UNIQUE INDEX index_follows_on_follower_id_and_followed_id 
ON follows (follower_id, followed_id);

```

-   Single-column indexes support lookups in both directions
-   Unique composite index prevents duplicate follow relationships

### Cache Strategy

The application implements a multi-layer caching strategy using Rails cache (backed by Redis):

#### Layer 0: Base Data Cache (Long Duration)

```ruby
# User object cache - 1 day
cache_key = "user_object_#{user_id}"
Rails.cache.fetch(cache_key, expires_in: 1.day)

# Following IDs cache - 1 day (invalidated on follow/unfollow)
cache_key = "user_#{user_id}_following_ids"
Rails.cache.fetch(cache_key, expires_in: 1.day)

```

**Why long duration?**

-   User data and follow relationships change infrequently
-   Explicitly invalidated when follows/unfollows occur
-   Reduces database load for frequently accessed data

#### Layer 1: Paginated Response Cache (Short Duration)

```ruby
# Sleep records list cache - 2 minutes
cache_key = "user_#{user_id}_sleep_records_page_#{page}_per_#{per_page}_data"
Rails.cache.fetch(cache_key, expires_in: 2.minutes)

```

**Why short duration?**

-   Balance between freshness and performance
-   Sleep records change when users clock in/out
-   2-minute window acceptable for most use cases

#### Layer 2: Count Cache (Medium Duration)

```ruby
# Total count cache - 10 minutes with race condition TTL
cache_key = "followings_sleep_records_count:#{user_id}"
Rails.cache.fetch(cache_key, expires_in: 10.minutes, race_condition_ttl: 30.seconds)

```

**Why race condition TTL?**

-   Prevents cache stampede when multiple requests hit expired cache simultaneously
-   First request regenerates while others wait briefly

----------

## API Endpoints

### 1. Clock In/Out API

**Endpoint:** `POST /api/v1/users/:user_id/clock_ins`

**Purpose:** Record sleep sessions (both start and end)

**Request Parameters:**

| Parameter | Type    | Required | Description                           |
|-----------|---------|----------|---------------------------------------|
| user_id   | integer | Yes      | User ID (in URL path)                |
| page      | integer | No       | Page number for pagination (default: 1) |
| per_page  | integer | No       | Records per page (default: 20)       |



**Success Response (201 Created):**

```json
{
  "success": true,
  "message": "Success to record",
  "data": {
    "sleep_records": [
      {
        "id": 1,
        "user_id": 1,
        "clock_in_time": "2025-10-24T10:00:00.000Z",
        "clock_out_time": "2025-10-24T18:00:00.000Z",
        "duration": 28800,
        "created_at": "2025-10-24T10:00:00.000Z",
        "updated_at": "2025-10-24T18:00:00.000Z",
        "user_name": "Alice Johnson"
      }
    ],
    "pagination": {
      "current_page": 1,
      "per_page": 20,
      "total_pages": 1,
      "total_count": 1
    }
  }
}

```

**Error Response (404 Not Found):**

```json
{
  "success": false,
  "message": "User not found",
  "errors": ["User with the given ID does not exist"]
}

```

**Error Response (422 Unprocessable Content):**

```json
{
  "success": false,
  "message": "Failed to record",
  "errors": ["Minimum sleep duration is 60 seconds. Current: 30 seconds."]
}

```

#### Technical Flow

1.  **Validate user exists**
2.  **Check current session state:**
    -   If **not clocked in**: Create new sleep record with `clock_in_time = Time.current`, `clock_out_time = nil`
    -   If **already clocked in**:
        -   Calculate duration: `Time.current - clock_in_time`
        -   Validate minimum duration (600 seconds)
        -   Update existing record: set `clock_out_time` and `duration`
3.  **Load paginated sleep records** from cache or database
4.  **Return JSON response** with sleep records and pagination metadata

#### Handling Heavy Load

**Service Layer Pattern:**

-   `ClockInService` encapsulates business logic, separating concerns from controller
-   Enables easier testing and reusability

**Transaction Safety:**

-   Uses `ActiveRecord::Base.transaction` to ensure atomic operations
-   Prevents partial updates if any step fails

**Pagination:**

-   Required parameter to prevent loading all records at once
-   Default page size: 20 records
-   Reduces memory usage and response time

**Caching:**

```ruby
cache_key = "user_#{user_id}_sleep_records_page_#{page}_per_#{per_page}_data"
Rails.cache.fetch(cache_key, expires_in: 2.minutes) do
  {
    records: user.sleep_records.order(created_at: :desc).page(page).per(per_page),
    total_count: user.sleep_records.count,
    total_pages: (total_count / per_page).ceil
  }
end

```

**Validation:**

-   Minimum duration validation prevents accidental double clock-ins
-   Prevents database pollution with invalid records

----------

### 2. Follow User API

**Endpoint:** `POST /api/v1/users/:user_id/follows`

**Purpose:** Create a follow relationship

**Request Parameters:**

| Parameter   | Type    | Required | Description                        |
|-------------|---------|----------|------------------------------------|
| user_id     | integer | Yes      | Follower user ID (in URL path)     |
| followed_id | integer | Yes      | User ID to follow (in request body)|

**Success Response (201 Created):**

```json
{
  "success": true,
  "message": "Successfully followed",
  "data": {
    "id": 1,
    "follower_id": 1,
    "followed_id": 2,
    "follower_name": "Alice Johnson",
    "followed_name": "Bob Smith"
  }
}

```

**Error Response (422 Unprocessable Content):**

```json
{
  "success": false,
  "message": "Failed to follow",
  "errors": ["Follower is already following this user"]
}

```

#### Technical Flow

1.  **Validate both users exist**
2.  **Validate business rules:**
    -   Cannot follow yourself
    -   Cannot follow the same user twice (unique constraint)
3.  **Create follow record**
4.  **Invalidate cache:** Clear `following_ids` cache for the follower
5.  **Return JSON response** with follow relationship details

#### Handling Heavy Load

**Service Layer Pattern:**

-   `FollowService` handles all validation and business logic
-   Separation of concerns improves maintainability

**Database Constraints:**

-   Unique index on `(follower_id, followed_id)` prevents race conditions
-   Database-level constraint is faster than application-level checking

**Cache Invalidation:**

```ruby
def invalidate_cache_following_ids
  cache_key = "user_#{follower_id}_following_ids"
  Rails.cache.delete(cache_key)
end

```

-   Ensures fresh data after follow/unfollow operations
-   Only invalidates affected user's cache

----------

### 3. Unfollow User API

**Endpoint:** `DELETE /api/v1/users/:user_id/follows/:id`

**Purpose:** Remove a follow relationship

**Request Parameters:**

| Parameter | Type   | Required | Description                      |
|-----------|--------|----------|----------------------------------|
| user_id   | integer| Yes      | Follower's user ID (path parameter) |
| id        | integer| Yes      | Followed user's ID (path parameter) |

**Success Response**

| Status Code | Description |
|-------------|-------------|
| 200 OK      | Success     |

**Success Response (200 OK):**

```json
{
  "success": true,
  "message": "Successfully unfollowed",
  "data": {
    "id": 1,
    "follower_id": 1,
    "followed_id": 2,
    "follower_name": "Alice Johnson",
    "followed_name": "Bob Smith"
  }
}

```

**Error Response (422 Unprocessable Content):**

```json
{
  "success": false,
  "message": "Failed to unfollow",
  "errors": ["Not following this user"]
}

```

#### Technical Flow

1.  **Validate both users exist**
2.  **Find follow relationship** by follower_id and followed_id
3.  **Delete follow record** if exists
4.  **Invalidate cache:** Clear `following_ids` cache
5.  **Return JSON response** with deleted relationship details

#### Handling Heavy Load

Same strategies as Follow API, with additional:

**Soft validation:**

-   Only checks if users exist before attempting delete
-   Database handles "not found" case efficiently

----------

### 4. Following Users' Sleep Records API

**Endpoint:** `GET /api/v1/users/:user_id/followings/sleep_records`

**Purpose:** Retrieve sleep records from all following users for the past week, sorted by duration desc

**Request Parameters:**
| Parameter | Type    | Required | Description                           |
|-----------|---------|----------|---------------------------------------|
| user_id   | integer | Yes      | User ID (in URL path)                |
| page      | integer | No       | Page number (default: 1)             |
| per_page  | integer | No       | Records per page (default: 20)       |



**Success Response (200 OK):**

```json
{
  "success": true,
  "message": "Success",
  "data": {
    "sleep_records": [
      {
        "id": 3,
        "user_id": 2,
        "clock_in_time": "2025-10-21T22:00:00.000Z",
        "clock_out_time": "2025-10-22T07:00:00.000Z",
        "duration": 32400,
        "created_at": "2025-10-21T22:00:00.000Z",
        "updated_at": "2025-10-22T07:00:00.000Z",
        "user_name": "Bob Smith"
      },
      {
        "id": 1,
        "user_id": 1,
        "clock_in_time": "2025-10-21T23:00:00.000Z",
        "clock_out_time": "2025-10-22T07:00:00.000Z",
        "duration": 28800,
        "created_at": "2025-10-21T23:00:00.000Z",
        "updated_at": "2025-10-22T07:00:00.000Z",
        "user_name": "Alice Johnson"
      }
    ],
    "pagination": {
      "current_page": 1,
      "per_page": 20,
      "total_pages": 1,
      "total_count": 2
    }
  }
}

```

**Error Response (422 Unprocessable Content):**

```json
{
  "success": false,
  "message": "Failed to fetch data",
  "errors": ["You don't have any following data"]
}

```

#### Technical Flow

1.  **Fetch user from cache** (Layer 0 - 1 day TTL)
2.  **Fetch following IDs from cache** (Layer 0 - 1 day TTL)
3.  **Check cache for paginated results** (Layer 1 - 2 minutes TTL)
4.  **If cache miss:**
    -   Fetch total count from cache (Layer 2 - 10 minutes TTL)
    -   Query TimescaleDB hypertable with optimized filtering using index and benefit from hypertable
5.  **Build pagination metadata**
6.  **Cache results and return response**

#### Multi-Layer Cache Strategy

**Layer 0: User & Following IDs (1 day TTL)**

```ruby
# User cache
user = Rails.cache.fetch("user_object_#{user_id}", expires_in: 1.day) do
  User.find_by(id: user_id)
end

# Following IDs cache
following_ids = Rails.cache.fetch("user_#{user_id}_following_ids", expires_in: 1.day) do
  user.following.pluck(:id)
end

```

**Why long TTL?**

-   User data only have id and name assume rarely changed. If there's API to update user, we will invalidate the cache too. But currently this outside of scope requirement.
-   Follow relationships change infrequently
-   Reduces database queries significantly
-   Explicitly invalidated on follow/unfollow events

**Layer 1: Paginated Sleep Records (2 minutes TTL)**

```ruby
cache_key = "followings_sleep_records_#{user_id}_#{page}_#{per_page}"
Rails.cache.fetch(cache_key, expires_in: 2.minutes) do
  records = SleepRecord.paginated_by_users(following_ids, page, per_page)
  [records, build_pagination(total_count, page, per_page)]
end

```

**Why short TTL?**

-   Sleep records update when users clock in/out
-   Balance between freshness and performance
-   Different pages cached separately for optimal hit rate

**Layer 2: Total Count (10 minutes TTL + Race Condition Protection)**

```ruby
cache_key = "followings_sleep_records_count:#{user_id}"
Rails.cache.fetch(cache_key, expires_in: 10.minutes, race_condition_ttl: 30.seconds) do
  SleepRecord.count_by_users(following_ids)
end

```

**Why race condition TTL?**

-   Prevents cache stampede when count expires
-   Multiple concurrent requests don't all hit the database
-   First request regenerates, others wait briefly

#### Optimized Query for Large Following Lists

**The Challenge:** Standard `WHERE IN` queries become inefficient with large following lists (100+ users).

**The Solution:** Dynamic query strategy based on following count:

```ruby
def self.apply_user_filter(relation, following_ids)
  safe_following_ids = following_ids.map(&:to_i).reject(&:zero?).uniq
  
  if safe_following_ids.size <= 100  # Configurable threshold
    # Use WHERE IN for small lists
    relation.where(user_id: safe_following_ids)
  else
    # Use VALUES JOIN for large lists
    placeholders = Array.new(safe_following_ids.size, "(?)").join(",")
    sql = "sleep_records 
           INNER JOIN (VALUES #{placeholders}) AS user_ids(id)
           ON sleep_records.user_id = user_ids.id"
    relation.from(sanitize_sql_array([sql, *safe_following_ids]))
  end
end

```

**Why this approach?**

**For ≤100 following users (WHERE IN):**

-   PostgreSQL efficiently uses index scans
-   Simple query plan, fast execution
-   Typical for most users

**For >100 following users (VALUES JOIN):**

-   Creates temporary table with user IDs
-   PostgreSQL optimizer can use hash join
-   Prevents query plan degradation with large IN lists
-   Maintains consistent performance regardless of list size

**Security:**

-   All IDs sanitized using `sanitize_sql_array`
-   Prevents SQL injection
-   Integer type coercion (`to_i`) ensures data type safety

#### Why TimescaleDB for This Use Case

**Time-Range Filtering (Last 7 Days):**

```ruby
scope :this_week, -> { where(clock_in_time: 1.week.ago..Time.current) }

```

-   TimescaleDB's chunk-based partitioning only scans relevant chunks
-   Queries hitting recent data are extremely fast
-   Old data chunks are compressed, saving 90% storage

**Automatic Compression:**

-   Data older than 7 days automatically compressed
-   Compression preserves query capability
-   Reduces storage costs significantly for high-volume data

**Data Retention:**

-   Automatically drops data older than 30 days
-   Maintains database performance as data grows
-   No manual cleanup jobs required

**Optimized for Sorted Queries:**

```ruby
.order(duration: :desc)

```

-   Compression is ordered by `clock_in_time DESC`
-   Index includes `duration DESC`
-   Combining time filtering + sorting is highly optimized

**Concurrent Access:**

-   TimescaleDB handles concurrent reads efficiently
-   No table-level locks for SELECT queries
-   Scales well with increasing user base

----------

## Continuous Integration

### GitHub Actions Workflow

The project includes automated CI pipeline with three jobs:

#### 1. Security Scanning (`scan_ruby`)

```yaml
- name: Scan for common Rails security vulnerabilities using static analysis
  run: bin/brakeman --no-pager

```

**Brakeman** performs static analysis to detect:

-   SQL injection vulnerabilities
-   Cross-site scripting (XSS)
-   Command injection
-   Mass assignment vulnerabilities
-   Dangerous redirect patterns
-   Insecure configuration

#### 2. Code Linting (`lint`)

```yaml
- name: Lint code for consistent style
  run: bin/rubocop -f github

```

**RuboCop** (rails-omakase configuration) ensures:

-   Consistent code style across the project
-   Ruby and Rails best practices
-   Performance optimizations
-   Code complexity management
-   GitHub-formatted output for easy review

#### 3. Automated Testing (`test`)

```yaml
- name: Run tests
  run: bundle exec rspec

```

**RSpec Test Suite** includes:

-   **Model specs**: Validations, associations, callbacks
-   **Request specs**: API endpoint functionality
-   **Service specs**: Business logic testing
-   **Factory specs**: Test data generation

**Test Environment:**

-   PostgreSQL with TimescaleDB extension
-   Redis for caching
-   Chrome browser for system tests (if needed)

#### Test Coverage:

-   **Models**: User, SleepRecord, Follow
-   **Controllers**: ClockIns, Follows, FollowingsSleepRecords
-   **Services**: ClockInService, FollowService, FollowingsSleepRecordsService
-   **Blueprints**: SleepRecordBlueprint, FollowBlueprint

### Dependabot Configuration

```yaml
version: 2
updates:
  - package-ecosystem: bundler
    directory: "/"
    schedule:
      interval: daily
    open-pull-requests-limit: 10
  
  - package-ecosystem: github-actions
    directory: "/"
    schedule:
      interval: daily
    open-pull-requests-limit: 10

```

**Benefits:**

-   **Automated dependency updates**: Daily checks for new versions
-   **Security patches**: Immediately notified of vulnerabilities
-   **Reduced maintenance burden**: PRs automatically created, you can see the open MR for examples
-   **Separate tracking**: Bundler gems and GitHub Actions updated independently

----------

## Getting Started - Local setup

### Prerequisites

-   [Docker](https://docs.docker.com/get-docker/)
-   [Docker Compose](https://docs.docker.com/compose/)

### Setup & Run

Copy `.env.example` to `.env` and edit if needed.

0.  **All docker commands must run with `./docker-compose-run.sh`,** so make it executable:
    
    ```sh
    chmod +x docker-compose-run.sh
    
    ```
    
1.  **Build containers:**
    
    ```sh
    docker-compose build
    
    ```
    
2.  **Set up the database:** (Runs database migrations and seeds)
    
    ```sh
    ./docker-compose-run.sh api bin/rails db:migrate
    ./docker-compose-run.sh api bin/rails db:setup
    
    ```
    
3.  **Seed sample data:** (Creates sample users, sleep records, and follow relationships)
    
    ```sh
    ./docker-compose-run.sh api bin/rails db:seed
    
    ```
    
4.  **Start the full stack:**
    
    ```sh
    ./docker-compose-run.sh up
    
    ```
    
    Rails API will be available at http://localhost:3000
    
5.  **Stop services:** Press Ctrl-C or run:
    
    ```sh
    ./docker-compose-run.sh down
    
    ```
    

### Useful Commands

-   **Rails Console:**
    
    ```sh
    ./docker-compose-run.sh api bin/rails console
    
    ```
    
-   **Run database migrations manually:**
    
    ```sh
    ./docker-compose-run.sh api bin/rails db:migrate
    
    ```
    
-   **Seed sample data:**
    
    ```sh
    ./docker-compose-run.sh api bin/rails db:seed
    
    ```
    
-   **Run RuboCop:**
    
    ```sh
    ./docker-compose-run.sh api bundle exec rubocop -f github
    
    ```
    
-   **Run tests:**
    
    ```sh
    ./docker-compose-run.sh api bundle exec rspec
    
    ```
    

## Technology Stack

-   **Ruby on Rails 8.0.3** (API-only)
-   **PostgreSQL 16** with **TimescaleDB** extension (Database)
-   **Redis** (Cache/Background Jobs)
-   **Docker Compose** (Container orchestration)
-   **Kaminari** (Pagination)
-   **Blueprinter** (JSON serialization)
-   **RSpec** (Testing framework)
-   **FactoryBot** (Test data generation)
-   **Shoulda Matchers** (Test helpers)
-   **RuboCop** (Code linting)
-   **Brakeman** (Security scanning)