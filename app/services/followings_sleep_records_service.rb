class FollowingsSleepRecordsService
  include ActiveModel::Model
  include ActiveModel::Attributes

  attr_reader :sleep_records, :pagination

  attribute :user_id, :integer
  attribute :page, :integer, default: 1
  attribute :per_page, :integer, default: 20

  validates :user_id, presence: true

  def call
    return false unless valid?
    user = User.includes(:following).find_by(id: user_id)
    return false unless user

    following_ids = user.following.select(:id)

    # Collect last 1 week of sleep records for all followings
    # Use includes(:user) for Blueprinter
    relation = SleepRecord.includes(:user)
      .where(user_id: following_ids)
      .where(clock_in_time: 1.week.ago..Time.current)
      .where.not(clock_out_time: nil)

    cache_key = "followings_sleep_records_user_#{user.id}_page_#{page}_per_#{per_page}_max_updated_#{relation.maximum(:updated_at)&.to_i}"
    expires_in = Rails.configuration.sleep_record.cache_duration
    @sleep_records = Rails.cache.fetch(cache_key, expires_in: expires_in) do
      relation.order(duration: :desc).page(page).per(per_page).to_a
    end
    total_count = relation.count
    @pagination = {
      current_page: page,
      per_page: per_page,
      total_pages: (total_count / per_page.to_f).ceil,
      total_count: total_count
    }
    true
  rescue => e
    errors.add(:base, "Failed to load followings' sleep records: #{e.message}")
    false
  end
end
