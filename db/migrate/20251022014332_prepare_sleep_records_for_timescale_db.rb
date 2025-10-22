class PrepareSleepRecordsForTimescaleDb < ActiveRecord::Migration[8.0]

  def up
    return unless extension_enabled?('timescaledb')

    # 0. prepare the tables column 
    change_column :sleep_records, :clock_in_time, :timestamptz
    change_column :sleep_records, :clock_out_time, :timestamptz

    # 1. First, drop the existing primary key constraint
    execute "ALTER TABLE sleep_records DROP CONSTRAINT IF EXISTS sleep_records_pkey"

    # 2. Create a new composite primary key that includes clock_in_time
    execute "ALTER TABLE sleep_records ADD PRIMARY KEY (id, clock_in_time)"

    puts "✓ Primary key updated for TimescaleDB compatibility"
  end

  def down
    return unless extension_enabled?('timescaledb')

    # 0. prepare the tables column 
    change_column :sleep_records, :clock_in_time, :datetime
    change_column :sleep_records, :clock_out_time, :datetime

    # 1. Drop the composite primary key
    execute "ALTER TABLE sleep_records DROP CONSTRAINT sleep_records_pkey"

    # 2. Restore original primary key
    execute "ALTER TABLE sleep_records ADD PRIMARY KEY (id)"

    puts "✓ Primary key restored to original state"
  end
end
