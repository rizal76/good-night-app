class ClockInService
  include ActiveModel::Model
  include ActiveModel::Attributes

  attr_reader :sleep_record, :sleep_records, :pagination

  attribute :user_id, :integer
  attribute :clock_in_time, :datetime
  attribute :page, :integer, default: 1
  attribute :per_page, :integer, default: 20

  validates :user_id, presence: true
  validates :clock_in_time, presence: true
  validate :user_exists
  validate :clock_in_time_not_future

  def initialize(attributes = {})
    super
    self.clock_in_time = Time.current unless attributes.key?(:clock_in_time)
  end

  def call
    return false unless valid?

    ActiveRecord::Base.transaction do
      if user.is_clocked_in?
        last_record = user.current_sleep_session
        duration = Time.current - last_record.clock_in_time
        if duration < min_duration
          errors.add(:base, "Minimum sleep duration is #{min_duration.to_i} seconds. Current: #{duration.to_i} seconds.")
          raise ActiveRecord::Rollback
        end
        last_record.update!(clock_out_time: Time.current, duration: duration.to_i)
        @sleep_record = last_record
      else
        @sleep_record = user.sleep_records.create!(clock_in_time: clock_in_time)
      end
    end
    
    load_sleep_records
    true
  rescue => e
    errors.add(:base, "Failed to clock in: #{e.message}")
    false
  end

  private

  def user
    @user ||= User.find_by(id: user_id)
  end

  def user_exists
    return if user.present?
    errors.add(:user_id, 'User not found')
  end

  def clock_in_time_not_future
    return unless clock_in_time && clock_in_time > Time.current
    errors.add(:clock_in_time, 'cannot be in the future')
  end

  def min_duration
    Rails.configuration.sleep.min_duration_seconds
  end

  def load_sleep_records
    cache_key = "user_#{user.id}_sleep_records_page_#{page}_per_#{per_page}_#{user.sleep_records.maximum(:updated_at)&.to_i}"
    @sleep_records = Rails.cache.fetch(cache_key, expires_in: 2.minutes) do
      user.sleep_records.order(created_at: :desc).page(page).per(per_page).to_a
    end
    @pagination = {
      current_page: page,
      per_page: per_page,
      total_pages: user.sleep_records.page(page).per(per_page).total_pages,
      total_count: user.sleep_records.count
    }
  end
end