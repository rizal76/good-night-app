class OptimizeIndexSleepRecords < ActiveRecord::Migration[8.0]
  def change
    # Remove not optimize column indexes that are covered by composite index
    remove_index :sleep_records, name: "index_sleep_records_on_user_id" if index_exists?(:sleep_records, :user_id)
    remove_index :sleep_records, name: "index_sleep_records_on_clock_in_time" if index_exists?(:sleep_records, :clock_in_time)
    remove_index :sleep_records, name: "index_sleep_records_on_duration" if index_exists?(:sleep_records, :duration)

    # Add index based on frequent query on fetching following user sleep record
    # with some filter and sort
    # this based on ERS Rule (Equality - Range - Sort) standard
    execute <<~SQL
      CREATE INDEX idx_sleep_records_optimized
      ON sleep_records (user_id, clock_in_time, duration DESC)#{' '}
      WHERE clock_out_time IS NOT NULL;
    SQL
  end
end
