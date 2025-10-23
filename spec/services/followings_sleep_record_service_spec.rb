require 'rails_helper'

RSpec.describe FollowingsSleepRecordsService, type: :service do
  describe '#call' do
    context 'when valid params' do
      let(:user) { create(:user) }
      let(:following_user_1) { create(:user) }
      let(:following_user_2) { create(:user) }

      let(:service) { described_class.new(user_id: user.id, page: 1, per_page: 2) }

      before do
        create(:follow, follower: user, followed: following_user_1)
        create(:follow, follower: user, followed: following_user_2)

        base_time = 3.days.ago.change(usec: 0)

        @sleep_record_longest = following_user_2.sleep_records.create!(
          clock_in_time: microsecond_time(base_time),
          clock_out_time: microsecond_time(base_time + 3.hours)  # 10800s
        )

        @sleep_record_medium = following_user_1.sleep_records.create!(
          clock_in_time: microsecond_time(base_time),
          clock_out_time: microsecond_time(base_time + 2.hours)  # 7200s
        )

        @sleep_record_shortest = following_user_1.sleep_records.create!(
          clock_in_time: microsecond_time(base_time),
          clock_out_time: microsecond_time(base_time + 1.hour)   # 3600s
        )
      end

      it 'returns true' do
        expect(service.call).to be true
      end

      it 'returns sleep records ordered by duration DESC' do
        service.call
        expect(service.sleep_records.map(&:duration)).to eq([ 10800, 7200 ])
      end

      it 'returns correct pagination' do
        service.call
        expect(service.pagination).to eq({
          current_page: 1,
          per_page: 2,
          total_pages: 2,
          total_count: 3
        })
      end

      context 'pagination' do
        it 'returns first page correctly' do
          service.call
          expect(service.sleep_records.size).to eq(2)
          expect(service.sleep_records.first.duration).to eq(10800)  # 3 hours
          expect(service.sleep_records.second.duration).to eq(7200)  # 2 hours
        end

        it 'returns second page correctly' do
          service2 = described_class.new(user_id: user.id, page: 2, per_page: 2)
          service2.call
          expect(service2.sleep_records.size).to eq(1)
          expect(service2.sleep_records.first.duration).to eq(3600)  # 1 hour
        end
      end
    end

    context 'when user_id is missing' do
      let(:service) { described_class.new(user_id: nil) }

      it 'returns false' do
        expect(service.call).to be false
      end

      it 'adds validation error' do
        service.call
        expect(service.errors[:user_id]).to include("can't be blank")
      end
    end

    context 'when user has no followings' do
      let(:user_without_followings) { create(:user) }
      let(:service) { described_class.new(user_id: user_without_followings.id) }

      it 'returns false' do
        expect(service.call).to be false
      end

      it 'adds appropriate error message' do
        service.call
        expect(service.errors[:base]).to include("You don't have any following data")
      end
    end

    context 'when user does not exist' do
      let(:service) { described_class.new(user_id: 999999) }

      it 'returns false' do
        expect(service.call).to be false
      end
    end
  end

  describe 'edge cases' do
    let(:user) { create(:user) }
    let(:following_user) { create(:user) }

    before do
      create(:follow, follower: user, followed: following_user)

      base_time = 3.days.ago.change(usec: 0)
      following_user.sleep_records.create!(
        clock_in_time: microsecond_time(base_time),
        clock_out_time: microsecond_time(base_time + 2.hours)
      )
    end

    it 'handles zero records gracefully' do
      SleepRecord.delete_all
      service = described_class.new(user_id: user.id, page: 1, per_page: 20)
      expect(service.call).to be true
      expect(service.sleep_records).to eq([])
      expect(service.pagination[:total_count]).to eq(0)
      expect(service.pagination[:total_pages]).to eq(0)
    end
  end

  describe 'caching layers' do
    let(:user) { create(:user) }
    let(:following_user) { create(:user) }

    before do
      create(:follow, follower: user, followed: following_user)
      base_time = 3.days.ago.change(usec: 0)
      following_user.sleep_records.create!(
        clock_in_time: microsecond_time(base_time),
        clock_out_time: microsecond_time(base_time + 2.hours)
      )
      Rails.cache.clear
    end

    let(:service) { described_class.new(user_id: user.id, page: 1, per_page: 2) }

    it 'caches Layer 1: full paginated response' do
      expect {
        service.call
      }.to change { Rails.cache.exist?(CacheKeyHelper.followings_sleep_records_key(user.id, 1, 2)) }.from(false).to(true)
    end

    it 'caches Layer 2: total count' do
      expect {
        service.call
      }.to change { Rails.cache.exist?(CacheKeyHelper.followings_sleep_records_count(user.id)) }.from(false).to(true)
    end
  end

  describe 'scopes usage' do
    let(:user) { create(:user) }
    let(:following_user) { create(:user) }

    before do
      create(:follow, follower: user, followed: following_user)
      Rails.cache.clear
    end

    it 'only returns this_week records' do
      base_time = 3.days.ago.change(usec: 0)
      # This week
      following_user.sleep_records.create!(
        clock_in_time: microsecond_time(base_time),
        clock_out_time: microsecond_time(base_time + 1.hour)
      )
      # Last week
      following_user.sleep_records.create!(
        clock_in_time: microsecond_time(10.days.ago),
        clock_out_time: microsecond_time(9.days.ago)
      )

      service = described_class.new(user_id: user.id, page: 1, per_page: 10)
      service.call
      expect(service.sleep_records.all? { |r| r.clock_in_time > 1.week.ago }).to be true
    end

    it 'only returns clocked_out records' do
      base_time = 3.days.ago.change(usec: 0)
      # Clocked out
      following_user.sleep_records.create!(
        clock_in_time: microsecond_time(base_time),
        clock_out_time: microsecond_time(base_time + 1.hour)
      )
      # Not clocked out
      following_user.sleep_records.create!(
        clock_in_time: microsecond_time(base_time),
        clock_out_time: nil
      )

      service = described_class.new(user_id: user.id, page: 1, per_page: 10)
      service.call
      expect(service.sleep_records.all? { |r| r.clock_out_time.present? }).to be true
    end
  end
end
