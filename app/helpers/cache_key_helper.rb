# This helper to make sure the cache key is same across code
# Prevent redundant writing the keys
module CacheKeyHelper
    def self.following_ids_key(user_id)
      "user_#{user_id}_following_ids"
    end

    def self.user_key(user_id)
        "user_object_#{user_id}"
    end

    def self.user_sleep_record_data_key(user_id, page, per_page)
      "user_#{user_id}_sleep_records_page_#{page}_per_#{per_page}_data"
    end

    def self.followings_sleep_records_key(user_id, page, per_page)
      "followings_sleep_records_#{user_id}_#{page}_#{per_page}"
    end

    def self.followings_sleep_records_count(user_id)
      "followings_sleep_records_count:#{user_id}"
    end
end
