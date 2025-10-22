require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it { should have_many(:sleep_records).dependent(:destroy) }
    it { should have_many(:active_follows).class_name('Follow').with_foreign_key('follower_id').dependent(:destroy) }
    it { should have_many(:passive_follows).class_name('Follow').with_foreign_key('followed_id').dependent(:destroy) }
    it { should have_many(:following).through(:active_follows).source(:followed) }
    it { should have_many(:followers).through(:passive_follows).source(:follower) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_length_of(:name).is_at_least(2).is_at_most(100) }
  end

  describe 'scopes' do
    let!(:user1) { create(:user) }
    let!(:user2) { create(:user) }
    let!(:old_sleep_record) { create(:sleep_record, user: user1, clock_in_time: 2.days.ago, clock_out_time: 1.day.ago) }
    let!(:recent_sleep_record) { create(:sleep_record, user: user1, clock_in_time: 1.hour.ago, clock_out_time: 30.minutes.ago) }

    describe '.recent_sleep_records' do
      it 'returns users with sleep records ordered by most recent' do
        users = User.recent_sleep_records
        expect(users).to include(user1)
        expect(users).not_to include(user2)
      end
    end
  end

  describe 'instance methods' do
    let(:user) { create(:user) }

    describe '#current_sleep_session' do
      context 'when user has no sleep records' do
        it 'returns nil' do
          expect(user.current_sleep_session).to be_nil
        end
      end

      context 'when user has clocked out sleep records' do
        let!(:clocked_out_record) { create(:sleep_record, :clocked_out, user: user) }

        it 'returns nil' do
          expect(user.current_sleep_session).to be_nil
        end
      end

      context 'when user has clocked in sleep record' do
        expected_time = Time.parse("2025-10-22 09:18:09.495089000 +0000")
        let!(:clocked_in_record) { create(:sleep_record, user: user, clock_in_time: expected_time, clock_out_time: nil) }

        it 'returns the current sleep session' do
          expect(user.current_sleep_session).to eq(clocked_in_record)
        end
      end

      context 'when user has multiple sleep records' do
        let!(:old_clocked_in) { create(:sleep_record, user: user, clock_in_time: 2.hours.ago, clock_out_time: 1.hour.ago) }
        time_with_microseconds = 30.minutes.ago.change(usec: 30.minutes.ago.usec)
        let!(:current_clocked_in) { create(:sleep_record, user: user, clock_in_time: time_with_microseconds, clock_out_time: nil) }

        it 'returns the most recent clocked in record' do
          expect(user.current_sleep_session).to eq(current_clocked_in)
        end
      end
    end

    describe '#is_clocked_in?' do
      context 'when user is not clocked in' do
        it 'returns false' do
          expect(user.is_clocked_in?).to be_falsey
        end
      end

      context 'when user is clocked in' do
        let!(:clocked_in_record) { create(:sleep_record, user: user, clock_in_time: 1.hour.ago, clock_out_time: nil) }

        it 'returns true' do
          expect(user.is_clocked_in?).to be_truthy
        end
      end
    end

    describe '#last_clock_in_time' do
      context 'when user has no current sleep session' do
        it 'returns nil' do
          expect(user.last_clock_in_time).to be_nil
        end
      end
    end
  end

  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:user)).to be_valid
    end

    it 'creates a user with a name' do
      user = create(:user)
      expect(user.name).to be_present
    end
  end

  describe 'factory traits' do
    describe ':with_followers' do
      it 'creates a user with followers' do
        user = create(:user, :with_followers)
        expect(user.followers.count).to eq(2)
      end
    end

    describe ':with_following' do
      it 'creates a user with following' do
        user = create(:user, :with_following)
        expect(user.following.count).to eq(2)
      end
    end

    describe ':clocked_in' do
      it 'creates a clocked in user' do
        user = create(:user, :clocked_in)
        expect(user.is_clocked_in?).to be_truthy
      end
    end

    describe ':clocked_out' do
      it 'creates a clocked out user' do
        user = create(:user, :clocked_out)
        expect(user.is_clocked_in?).to be_falsey
      end
    end
  end
end
