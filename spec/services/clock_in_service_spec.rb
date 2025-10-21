# spec/services/clock_in_service_spec.rb

require 'rails_helper'

RSpec.describe ClockInService, type: :model do
  let(:user) { create(:user) }
  let(:valid_attributes) { { user_id: user.id, clock_in_time: Time.current } }

  describe 'attributes and validations' do
    it 'includes ActiveModel modules' do
      expect(ClockInService.include?(ActiveModel::Model)).to be true
      expect(ClockInService.include?(ActiveModel::Attributes)).to be true
    end

    it 'has correct attributes' do
      service = ClockInService.new
      expect(service).to respond_to(:user_id)
      expect(service).to respond_to(:clock_in_time)
      expect(service).to respond_to(:page)
      expect(service).to respond_to(:per_page)
    end

    it 'sets default clock_in_time to current time' do
      current_time = Time.current
      service = ClockInService.new(user_id: user.id)
      expect(service.clock_in_time).to be_within(1.second).of(current_time)
    end

    it 'sets default pagination parameters' do
      service = ClockInService.new(user_id: user.id)
      expect(service.page).to eq(1)
      expect(service.per_page).to eq(20)
    end

    it 'allows custom pagination parameters' do
      service = ClockInService.new(user_id: user.id, page: 2, per_page: 10)
      expect(service.page).to eq(2)
      expect(service.per_page).to eq(10)
    end
  end

  describe 'validations' do
    it 'is valid with correct attributes' do
      service = ClockInService.new(valid_attributes)
      expect(service).to be_valid
    end

    it 'validates presence of user_id' do
      service = ClockInService.new(clock_in_time: Time.current)
      expect(service).not_to be_valid
      expect(service.errors[:user_id]).to include("can't be blank")
    end

    it 'validates presence of clock_in_time' do
      service = ClockInService.new(user_id: user.id, clock_in_time: nil)
      expect(service).not_to be_valid
      expect(service.errors[:clock_in_time]).to include("can't be blank")
    end

    it 'validates user exists' do
      service = ClockInService.new(user_id: -1, clock_in_time: Time.current)
      expect(service).not_to be_valid
      expect(service.errors[:user_id]).to include('User not found')
    end

    it 'validates clock_in_time is not in future' do
      service = ClockInService.new(user_id: user.id, clock_in_time: 1.hour.from_now)
      expect(service).not_to be_valid
      expect(service.errors[:clock_in_time]).to include('cannot be in the future')
    end
  end

  describe '#call' do
    context 'when user is not clocked in' do
      before do
        # Ensure no active sessions and create some completed ones to avoid overlap
        create_list(:sleep_record, 2, :clocked_out, user: user)
      end

      it 'creates a new sleep record with clock_in_time' do
        clock_in_time = Time.current
        service = ClockInService.new(user_id: user.id, clock_in_time: clock_in_time)

        expect { service.call }.to change { user.sleep_records.count }.by(1)
        expect(service.call).to be true

        sleep_record = user.sleep_records.last
        expect(sleep_record.clock_in_time).to be_within(1.second).of(clock_in_time)
        expect(sleep_record.clock_out_time).to be_nil
        expect(sleep_record.duration).to be_nil
      end

      it 'uses current time when clock_in_time is not provided' do
        current_time = Time.current
        service = ClockInService.new(user_id: user.id)

        expect(service.call).to be true

        sleep_record = service.sleep_record
        expect(sleep_record.clock_in_time).to be_within(1.second).of(current_time)
      end

      it 'sets the sleep_record attribute' do
        service = ClockInService.new(valid_attributes)
        service.call

        expect(service.sleep_record).to be_a(SleepRecord)
        expect(service.sleep_record.user).to eq(user)
      end
    end

    context 'when user is already clocked in' do
      let!(:current_session) do
        # Create completed sessions first, then active session
        create(:sleep_record, :clocked_out, user: user, clock_in_time: 3.hours.ago, clock_out_time: 2.hours.ago)
        create(:sleep_record, user: user, clock_in_time: 2.hours.ago, clock_out_time: nil)
      end

      before do
        allow(Rails.configuration.sleep).to receive(:min_duration_seconds).and_return(300) # 5 minutes
      end

      it 'clocks out the current session and calculates duration' do
        current_time = Time.current
        service = ClockInService.new(valid_attributes)

        expect { service.call }.not_to change { user.sleep_records.count }
        expect(service.call).to be true

        current_session.reload
        expect(current_session.clock_out_time).to be_within(1.second).of(current_time)
        expected_duration = (current_time - current_session.clock_in_time).to_i
        expect(current_session.duration).to eq(expected_duration)
      end
    end

    context 'when service is invalid' do
      it 'returns false without creating records' do
        service = ClockInService.new(user_id: nil)

        expect { service.call }.not_to change { SleepRecord.count }
        expect(service.call).to be false
      end
    end

    context 'when exception occurs during transaction' do
      it 'handles exceptions and returns false' do
        service = ClockInService.new(valid_attributes)
        allow(service).to receive(:valid?).and_return(true)
        allow(service.send(:user)).to receive(:is_clocked_in?).and_raise(StandardError.new('Test error'))

        expect { service.call }.not_to change { SleepRecord.count }
        expect(service.call).to be false
        expect(service.errors[:base]).to include('Failed to clock in: Test error')
      end
    end

    it 'loads sleep records and pagination after successful call' do
      # Create only completed records to avoid overlap issues
      create_list(:sleep_record, 3, :clocked_out, user: user, clock_in_time: 4.hours.ago, clock_out_time: 3.hours.ago)
      service = ClockInService.new(valid_attributes.merge(page: 1, per_page: 2))

      expect(service.call).to be true

      expect(service.sleep_records).to be_present
      expect(service.sleep_records.size).to be <= 2 # due to pagination

      expect(service.pagination).to be_a(Hash)
      expect(service.pagination[:current_page]).to eq(1)
      expect(service.pagination[:per_page]).to eq(2)
      expect(service.pagination[:total_count]).to be >= 3
    end
  end

  describe 'caching' do
    it 'caches sleep records with proper cache key' do
      create_list(:sleep_record, 3, :clocked_out, user: user)
      service = ClockInService.new(valid_attributes.merge(page: 1, per_page: 2))

      expect(Rails.cache).to receive(:fetch).with(
        /user_#{user.id}_sleep_records_page_1_per_2_/,
        expires_in: 2.minutes
      )
      service.call
    end
  end
end
