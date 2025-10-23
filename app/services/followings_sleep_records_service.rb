class FollowingsSleepRecordsService
  include ActiveModel::Model
  include ActiveModel::Attributes

  attr_reader :sleep_records, :pagination

  attribute :user_id, :integer
  attribute :page, :integer, default: 1
  attribute :per_page, :integer, default: 20

  validates :user_id, presence: true

  def call
    return false unless valid?
    # We will using multi layer cache for better performance
    # **Layer 0: Base caches (optimized) - for user and followwing ids data**

    # fist process is get following ids for current user
    # Get user using cache
    user = fetch_user_with_cache
    return false unless user

    # Get following ids using cache, this we will cache with long duration
    # In this case 1 days is safe. Since we will invalidate when follow / unfollow happen
    following_ids = fetch_following_ids_with_cache(user)
    if following_ids.empty? # Early return for users with no followings
      errors.add(:base, "You don't have any following data")
      return false
    end

    # **Layer 1: Full paginated response - shorter duration**
    cache_key = CacheKeyHelper.followings_sleep_records_key(user.id, page, per_page)
    @sleep_records, @pagination = Rails.cache.fetch(cache_key, expires_in: cache_short_duration) do
      load_paginated_sleep_records(following_ids)
    end

    true
  rescue => e
    errors.add(:base, "Failed to load followings' sleep records: #{e.message}")
    false
  end

  private

  def fetch_user_with_cache
    cache_key = CacheKeyHelper.user_key(user_id)
    Rails.cache.fetch(cache_key, expires_in: Rails.configuration.sleep_record.cache_following_duration) do
      User.find_by(id: user_id)
    end
  end

  def fetch_following_ids_with_cache(user)
    cache_key = CacheKeyHelper.following_ids_key(user.id)

    Rails.cache.fetch(cache_key, expires_in: Rails.configuration.sleep_record.cache_following_duration) do
      user.following.pluck(:id)
    end
  end

  # **Layer 2: Get cache for total count and paginated sleep record - longer duration**
  def load_paginated_sleep_records(following_ids)
    # Get cached total count
    total_count = cached_total_count(user_id, following_ids)

    # Hit hypertable using timescaleDB - suitable for time based data - can handle heavy traffic
    # This is the most important part of the service
    # TimescaleDB also have capability for compression and data retention
    # This very suitable for this case, since in the requirement we only need last 7 days data
    records = SleepRecord.paginated_by_users(following_ids, page, per_page).to_a

    [
      records,
      build_pagination(total_count, page, per_page)
    ]
  end

  def cached_total_count(user_id, following_ids)
    cache_key = CacheKeyHelper.followings_sleep_records_count(user_id)
    Rails.cache.fetch(cache_key, expires_in: cache_longer_duration, race_condition_ttl: cache_race_condition_ttl) do
      SleepRecord.count_by_users(following_ids)
    end
  end

  def build_pagination(total_count, page, per_page)
    {
      current_page: page,
      per_page: per_page,
      total_pages: (total_count / per_page.to_f).ceil,
      total_count: total_count
    }
  end

  def cache_race_condition_ttl
    Rails.configuration.sleep_record.cache_race_condition_ttl
  end

  def cache_longer_duration
    Rails.configuration.sleep_record.longer_cache_duration
  end

  def cache_short_duration
    Rails.configuration.sleep_record.cache_duration
  end
end
