FactoryBot.define do
  factory :user do
    sequence(:name) { |n| "User #{n}" }

    trait :with_sleep_records do
      after(:create) do |user|
        create_list(:sleep_record, 3, user: user)
      end
    end

    trait :with_followers do
      after(:create) do |user|
        create_list(:follow, 2, followed: user)
      end
    end

    trait :with_following do
      after(:create) do |user|
        create_list(:follow, 2, follower: user)
      end
    end

    trait :clocked_in do
      after(:create) do |user|
        create(:sleep_record, user: user, clock_in_time: 1.hour.ago, clock_out_time: nil)
      end
    end

    trait :clocked_out do
      after(:create) do |user|
        create(:sleep_record, user: user, clock_in_time: 2.hours.ago, clock_out_time: 1.hour.ago)
      end
    end
  end
end
