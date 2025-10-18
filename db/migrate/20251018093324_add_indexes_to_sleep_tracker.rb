class AddIndexesToSleepTracker < ActiveRecord::Migration[8.0]
  def change
    # Indexes for sleep_records table
    add_index :sleep_records, [ :user_id, :created_at ], order: { created_at: :desc }
    add_index :sleep_records, :clock_in_time
    add_index :sleep_records, :duration

    # Note: follower_id and followed_id indexes are already created by foreign key references
  end
end
