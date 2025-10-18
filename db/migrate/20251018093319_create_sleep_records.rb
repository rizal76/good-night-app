class CreateSleepRecords < ActiveRecord::Migration[8.0]
  def change
    create_table :sleep_records do |t|
      t.references :user, null: false, foreign_key: true
      t.datetime :clock_in_time, null: false
      t.datetime :clock_out_time
      t.integer :duration # in minutes
      t.timestamps
    end
  end
end
