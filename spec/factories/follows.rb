FactoryBot.define do
  factory :follow do
    association :follower, factory: :user
    association :followed, factory: :user

    trait :with_different_users do
      transient do
        follower_name { "Follower User" }
        followed_name { "Followed User" }
      end

      after(:build) do |follow, evaluator|
        follow.follower = create(:user, name: evaluator.follower_name)
        follow.followed = create(:user, name: evaluator.followed_name)
      end
    end

    trait :self_follow do
      after(:build) do |follow|
        follow.followed = follow.follower
      end
    end
  end
end
