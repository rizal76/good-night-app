class ConvertSleepRecordsToHypertable < ActiveRecord::Migration[8.0]
  def up
    return unless extension_enabled?('timescaledb')

    # Check if table is already a hypertable
    result = execute <<~SQL
      SELECT EXISTS (
        SELECT 1 FROM timescaledb_information.hypertables#{' '}
        WHERE hypertable_name = 'sleep_records'
      ) as is_hypertable;
    SQL

    is_hypertable = result.first['is_hypertable']

    unless is_hypertable
      execute <<~SQL
        SELECT create_hypertable(
          'sleep_records',#{' '}
          'clock_in_time',
          chunk_time_interval => INTERVAL '1 day',
          if_not_exists => TRUE
        );
      SQL
    end
  end

  def down
    # Note: Hypertables cannot be directly reverted to normal tables
    # This would require creating a new table and migrating data
    if extension_enabled?('timescaledb')
      puts "WARNING: Cannot automatically revert hypertable conversion."
      puts "This would require manual intervention to recreate the table."
    end
  end
end
