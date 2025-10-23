# Clock-In API Usage Examples

## API Endpoints

### Clock In
**POST** `/api/v1/users/:user_id/clock_ins`

#### Request Examples

```bash
# Clock in with current time
curl -X POST http://localhost:3000/api/v1/users/1/clock_ins \
  -H "Content-Type: application/json"

# Clock in with specific time
curl -X POST http://localhost:3000/api/v1/users/1/clock_ins \
  -H "Content-Type: application/json" \
  -d '{"clock_in_time": "2024-01-20T10:30:00Z"}'
```

#### Success Response (201 Created)
```json
{
  "success": true,
  "message": "Successfully clocked in",
  "data": {
    "id": 123,
    "user_id": 1,
    "user_name": "John Doe",
    "clock_in_time": "2024-01-20T10:30:00Z",
    "clock_out_time": null,
    "created_at": "2024-01-20T10:30:00Z",
    "updated_at": "2024-01-20T10:30:00Z"
  }
}
```

#### Error Response (422 Unprocessable Entity)
```json
{
  "success": false,
  "message": "Failed to clock in",
  "errors": ["User is already clocked in"]
}
```

## Error Handling

### Common Error Responses

#### User Not Found (404)
```json
{
  "success": false,
  "message": "User not found",
  "errors": ["User with the given ID does not exist"]
}
```

#### Validation Errors (422)
```json
{
  "success": false,
  "message": "Failed to clock in",
  "errors": [
    "User is already clocked in",
    "Clock in time cannot be in the future"
  ]
}
```

#### Invalid Parameters (400)
```json
{
  "success": false,
  "message": "Invalid query parameters",
  "errors": [
    "Page must be greater than 0",
    "Per page must be greater than 0"
  ]
}
```

## Performance Features

### Database Optimization
- Optimized indexes for fast queries
- Efficient scoped queries
- Proper validation to prevent invalid data

### Simple and Fast
- No unnecessary caching for write operations
- Minimal dependencies
- Focus on core functionality

## Testing the API

### Using Rails Console
```ruby
# Create a test user
user = User.create!(name: "Test User")

# Test clock in service
service = ClockInService.new(user_id: user.id)
service.call

# Check if user is clocked in
user.is_clocked_in?
user.current_sleep_session
```

### Running Tests
```bash
# Run all tests
bin/rails test

# Run specific test files
bin/rails test test/controllers/api/v1/clock_ins_controller_test.rb
bin/rails test test/services/clock_in_service_test.rb
```

## Database Setup

### Run Migrations
```bash
bin/rails db:migrate
```

### Seed Data (Optional)
```ruby
# Create test users
User.create!(name: "Alice")
User.create!(name: "Bob")
User.create!(name: "Charlie")
```

## Monitoring

### Check API Health
```bash
curl -X GET http://localhost:3000/up
```

### Database Performance
```sql
-- Check index usage
EXPLAIN ANALYZE SELECT * FROM sleep_records 
WHERE user_id = 1 
ORDER BY created_at DESC 
LIMIT 20;
```

This API is designed to handle high traffic with efficient caching and database optimization strategies.
