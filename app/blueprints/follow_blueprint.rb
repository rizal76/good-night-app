class FollowBlueprint < Blueprinter::Base
  identifier :id

  fields :follower_id, :followed_id

  field :follower_name do |follow, _opts|
    follow.follower.name if follow.follower
  end

  field :followed_name do |follow, _opts|
    follow.followed.name if follow.followed
  end
end
