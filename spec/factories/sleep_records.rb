FactoryBot.define do
  factory :sleep_record do
    association :user
    clock_in_time { microsecond_time(Time.current) }
    clock_out_time { nil }
    duration { nil }

    trait :clocked_out do
      clock_in_time { microsecond_time(2.hours.ago) }
      clock_out_time { microsecond_time(1.hour.ago) }
      duration { 3600 } # 1 hour in seconds
    end

    trait :with_duration do
      clock_in_time { microsecond_time(3.hours.ago) }
      clock_out_time { microsecond_time(1.hour.ago) }
      duration { 7200 } # 2 hours in seconds
    end

    trait :this_week do
      clock_in_time { microsecond_time(3.days.ago) }
      clock_out_time { microsecond_time(2.days.ago) }
      duration { 86400 } # 1 day in seconds
    end

    trait :last_week do
      clock_in_time { microsecond_time(10.days.ago) }
      clock_out_time { microsecond_time(9.days.ago) }
      duration { 86400 } # 1 day in seconds
    end

    trait :overlapping do
      clock_in_time { microsecond_time(1.hour.ago) }
      clock_out_time { nil }
    end

    trait :short_duration do
      clock_in_time { microsecond_time(5.minutes.ago) }
      clock_out_time { microsecond_time(Time.current) }
      duration { 300 } # 5 minutes in seconds
    end

    trait :long_duration do
      clock_in_time { microsecond_time(12.hours.ago) }
      clock_out_time { microsecond_time(Time.current) }
      duration { 43200 } # 12 hours in seconds
    end
  end
end
