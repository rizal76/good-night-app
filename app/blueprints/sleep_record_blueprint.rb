class SleepRecordBlueprint < Blueprinter::Base
  identifier :id do |record, _opts|
    record.attributes["id"] # or record.read_attribute('id')
  end

  fields :user_id, :clock_in_time, :clock_out_time, :duration, :created_at, :updated_at

  field :user_name do |record, _opts|
    record.user.name
  end
end
