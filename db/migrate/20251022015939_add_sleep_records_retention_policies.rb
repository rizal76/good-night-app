class AddSleepRecordsRetentionPolicies < ActiveRecord::Migration[8.0]
  def up
    return unless extension_enabled?('timescaledb')

    # Check if retention policy already exists
    retention_exists = execute <<~SQL
      SELECT EXISTS (
        SELECT 1 FROM timescaledb_information.jobs 
        WHERE proc_name = 'policy_retention' 
        AND hypertable_name = 'sleep_records'
      ) as policy_exists;
    SQL

    unless retention_exists.first['policy_exists']
      execute <<~SQL
        SELECT add_retention_policy('sleep_records', INTERVAL '30 days');
      SQL
    end

    # Check if compression policy already exists
    compression_exists = execute <<~SQL
      SELECT EXISTS (
        SELECT 1 FROM timescaledb_information.jobs 
        WHERE proc_name = 'policy_compression' 
        AND hypertable_name = 'sleep_records'
      ) as policy_exists;
    SQL

    unless compression_exists.first['policy_exists']
      
      execute <<~SQL
        ALTER TABLE sleep_records SET (
          timescaledb.compress,
          timescaledb.compress_orderby = 'clock_in_time DESC'
        );
      SQL

      execute <<~SQL
        SELECT add_compression_policy('sleep_records', INTERVAL '7 days');
      SQL

    end
  end

  def down
    if extension_enabled?('timescaledb')
      execute <<~SQL
        SELECT remove_retention_policy('sleep_records');
        SELECT remove_compression_policy('sleep_records');
      SQL
    end
  end
end
