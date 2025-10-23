class SleepRecord < ApplicationRecord
  extend Timescaledb::ActsAsHypertable

  acts_as_hypertable(
    time_column: "clock_in_time",
    chunk_time_interval: "1 day",
    compress_orderby: "clock_in_time DESC",
    compress_after: "7 days",
    drop_after: "30 days"
  )
  # Associations
  belongs_to :user

  # Validations
  validates :clock_in_time, presence: true
  validate :clock_out_after_clock_in, if: :clock_out_time?
  validate :no_overlapping_sessions, on: :create

  # Scopes
  scope :clocked_in, -> { where(clock_out_time: nil) }
  scope :clocked_out, -> { where.not(clock_out_time: nil) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :this_week, -> { where(clock_in_time: 1.week.ago..Time.current) }

  # Callbacks
  before_save :calculate_duration, if: :clock_out_time?

  # Instance methods
  def clocked_out?
    clock_out_time.present?
  end

  def duration_in_hours
    return nil unless clocked_out?
    duration / 3600.0
  end

  def duration_in_minutes
    return nil unless clocked_out?
    duration / 60.0
  end

  private

  def clock_out_after_clock_in
    return unless clock_in_time && clock_out_time

    if clock_out_time <= clock_in_time
      errors.add(:clock_out_time, "must be after clock in time")
    end
  end

  def no_overlapping_sessions
    return unless user_id && clock_in_time

    overlapping = user.sleep_records.clocked_in
                    .where("clock_in_time <= ? AND (clock_out_time IS NULL OR clock_out_time > ?)",
                           clock_in_time, clock_in_time)

    if overlapping.exists?
      errors.add(:clock_in_time, "cannot overlap with existing sleep session")
    end
  end

  def calculate_duration
    return unless clock_in_time && clock_out_time

    self.duration = (clock_out_time - clock_in_time).to_i
  end

  def self.paginated_by_users(following_ids, page, per_page)
    return [] if following_ids.blank?
    
    base_relation = includes(:user)
    base_relation = self.apply_user_filter(base_relation, following_ids)
    
    base_relation
      .this_week
      .clocked_out
      .order(duration: :desc)
      .offset((page - 1) * per_page)
      .limit(per_page)
  end

  def self.count_by_users(following_ids)
    return 0 if following_ids.blank?

    base_relation = self
    base_relation = self.apply_user_filter(base_relation, following_ids)
    
    base_relation
      .this_week
      .clocked_out
      .count
  end

  private

  def self.apply_user_filter(relation, following_ids)
    # We treat as different due to for a lot of following_ids filter WHERE IN
    # will be not effecient so we use JOIN instead
    if following_ids.size <= Rails.configuration.sleep_record.normal_following_count
      relation.where(user_id: following_ids)
    else
      values_clause = following_ids.map { |id| "(#{id})" }.join(',')
      relation.from("sleep_records 
                     INNER JOIN (VALUES #{values_clause}) AS user_ids(id) 
                     ON sleep_records.user_id = user_ids.id")
    end
  end
end
