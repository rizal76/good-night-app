class FollowService
  include ActiveModel::Model
  include ActiveModel::Attributes

  attr_reader :follow

  attribute :follower_id, :integer
  attribute :followed_id, :integer

  validates :follower_id, :followed_id, presence: true
  validate :follower_and_followed_are_different
  validate :follower_exists
  validate :followed_exists

  def follow
    return nil unless valid?
    @follow = Follow.new(follower_id: follower_id, followed_id: followed_id)
    if @follow.save
      @follow
    else
      errors.merge!(@follow.errors)
      nil
    end
  end

  def unfollow
    return nil unless valid_for_unfollow?
    existing = Follow.find_by(follower_id: follower_id, followed_id: followed_id)
    if existing&.destroy
      existing
    else
      errors.add(:base, "Not following this user")
      nil
    end
  end

  private

  def follower_and_followed_are_different
    errors.add(:followed_id, "cannot follow yourself") if follower_id == followed_id
  end

  def follower_exists
    errors.add(:follower_id, "Follower user not found") if User.find_by(id: follower_id).nil?
  end

  def followed_exists
    errors.add(:followed_id, "Followed user not found") if User.find_by(id: followed_id).nil?
  end

  def valid_for_unfollow?
    errors.clear
    follower_exists
    followed_exists
    errors.empty?
  end
end
