class EnableTimescaledbExtension < ActiveRecord::Migration[8.0]
  def up
    # Check if TimescaleDB extension is available before enabling
    if extension_available?('timescaledb')
      enable_extension 'timescaledb' unless extension_enabled?('timescaledb')
    else
      puts "WARNING: TimescaleDB extension is not available. Continuing without it."
    end
  end

  def down
    if extension_enabled?('timescaledb')
      disable_extension 'timescaledb'
    end
  end

  private

  def extension_available?(extension_name)
    result = execute("SELECT * FROM pg_available_extensions WHERE name = '#{extension_name}'")
    result.any?
  rescue => e
    puts "Error checking extension availability: #{e.message}"
    false
  end
end
