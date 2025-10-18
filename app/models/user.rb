class User < ApplicationRecord
  # Associations
  has_many :sleep_records, dependent: :destroy
  has_many :active_follows, class_name: 'Follow', foreign_key: 'follower_id', dependent: :destroy
  has_many :passive_follows, class_name: 'Follow', foreign_key: 'followed_id', dependent: :destroy
  has_many :following, through: :active_follows, source: :followed
  has_many :followers, through: :passive_follows, source: :follower

  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }

  # Scopes
  scope :recent_sleep_records, -> { joins(:sleep_records).order('sleep_records.created_at DESC') }

  # Instance methods
  def current_sleep_session
    sleep_records.where(clock_out_time: nil).order(clock_in_time: :desc).first
  end

  def is_clocked_in?
    current_sleep_session.present?
  end

  def last_clock_in_time
    current_sleep_session&.clock_in_time
  end

end
