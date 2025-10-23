require 'rails_helper'

RSpec.describe SleepRecord, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
  end

  describe 'validations' do
    it { should validate_presence_of(:clock_in_time) }

    describe 'custom validations' do
      let(:user) { create(:user) }

      describe 'clock_out_after_clock_in' do
        context 'when clock_out_time is before clock_in_time' do
          let(:sleep_record) do
            build(:sleep_record,
                  user: user,
                  clock_in_time: 1.hour.ago,
                  clock_out_time: 2.hours.ago)
          end

          it 'is invalid' do
            expect(sleep_record).not_to be_valid
            expect(sleep_record.errors[:clock_out_time]).to include('must be after clock in time')
          end
        end

        context 'when clock_out_time is after clock_in_time' do
          let(:sleep_record) do
            build(:sleep_record,
                  user: user,
                  clock_in_time: 2.hours.ago,
                  clock_out_time: 1.hour.ago)
          end

          it 'is valid' do
            expect(sleep_record).to be_valid
          end
        end

        context 'when clock_out_time is nil' do
          let(:sleep_record) { build(:sleep_record, user: user, clock_out_time: nil) }

          it 'is valid' do
            expect(sleep_record).to be_valid
          end
        end
      end

      describe 'no_overlapping_sessions' do
        context 'when creating a new sleep record' do
          let!(:existing_record) do
            create(:sleep_record,
                   user: user,
                   clock_in_time: 2.hours.ago,
                   clock_out_time: nil)
          end

          context 'with overlapping clock_in_time' do
            let(:overlapping_record) do
              build(:sleep_record,
                    user: user,
                    clock_in_time: 1.hour.ago,
                    clock_out_time: nil)
            end

            it 'is invalid' do
              expect(overlapping_record).not_to be_valid
              expect(overlapping_record.errors[:clock_in_time]).to include('cannot overlap with existing sleep session')
            end
          end

          context 'with non-overlapping clock_in_time' do
            let(:non_overlapping_record) do
              build(:sleep_record,
                    user: user,
                    clock_in_time: 3.hours.ago,
                    clock_out_time: 2.5.hours.ago)
            end

            it 'is valid' do
              expect(non_overlapping_record).to be_valid
            end
          end
        end

        context 'when updating an existing sleep record' do
          let!(:existing_record) do
            create(:sleep_record,
                   user: user,
                   clock_in_time: 2.hours.ago,
                   clock_out_time: nil)
          end

          it 'allows updating the same record' do
            existing_record.clock_out_time = 1.hour.ago
            expect(existing_record).to be_valid
          end
        end
      end
    end
  end

  describe 'scopes' do
    let(:user) { create(:user) }
    let!(:clocked_in_record) { create(:sleep_record, user: user, clock_out_time: nil) }
    let!(:clocked_out_record) { create(:sleep_record, :clocked_out, user: user) }

    describe '.clocked_in' do
      it 'returns only clocked in records' do
        expect(SleepRecord.clocked_in).to include(clocked_in_record)
        expect(SleepRecord.clocked_in).not_to include(clocked_out_record)
      end
    end

    describe '.clocked_out' do
      it 'returns only clocked out records' do
        expect(SleepRecord.clocked_out).to include(clocked_out_record)
        expect(SleepRecord.clocked_out).not_to include(clocked_in_record)
      end
    end

    describe '.recent' do
      let!(:old_record) { create(:sleep_record, :clocked_out, user: user, created_at: 2.days.ago) }
      let!(:new_record) { create(:sleep_record, :clocked_out, user: user, created_at: Time.current) }

      it 'returns records ordered by created_at desc' do
        records = SleepRecord.recent
        expect(records.first).to eq(new_record)
        expect(records.last).to eq(old_record)
      end
    end

    describe '.by_user' do
      let(:other_user) { create(:user) }
      let!(:other_user_record) { create(:sleep_record, user: other_user) }

      it 'returns only records for the specified user' do
        records = SleepRecord.by_user(user.id)
        expect(records).to include(clocked_in_record)
        expect(records).to include(clocked_out_record)
        expect(records).not_to include(other_user_record)
      end
    end

    describe '.this_week' do
      let!(:this_week_record) { create(:sleep_record, :this_week, user: user) }
      let!(:last_week_record) { create(:sleep_record, :last_week, user: user) }

      it 'returns only records from this week' do
        records = SleepRecord.this_week
        expect(records).to include(this_week_record)
        expect(records).not_to include(last_week_record)
      end
    end
  end

  describe 'callbacks' do
    describe 'before_save :calculate_duration' do
      let(:user) { create(:user) }
      let(:clock_in_time) { 2.hours.ago }
      let(:clock_out_time) { 1.hour.ago }

      context 'when clock_out_time is present' do
        let(:sleep_record) do
          build(:sleep_record,
                user: user,
                clock_in_time: clock_in_time,
                clock_out_time: clock_out_time)
        end

        it 'calculates duration before saving' do
          sleep_record.save!
          expected_duration = (clock_out_time - clock_in_time).to_i
          expect(sleep_record.duration).to eq(expected_duration)
        end
      end

      context 'when clock_out_time is nil' do
        let(:sleep_record) do
          build(:sleep_record,
                user: user,
                clock_in_time: clock_in_time,
                clock_out_time: nil)
        end

        it 'does not calculate duration' do
          sleep_record.save!
          expect(sleep_record.duration).to be_nil
        end
      end
    end
  end

  describe 'instance methods' do
    let(:user) { create(:user) }

    describe '#clocked_out?' do
      context 'when clock_out_time is present' do
        let(:sleep_record) { build(:sleep_record, :clocked_out, user: user) }

        it 'returns true' do
          expect(sleep_record.clocked_out?).to be_truthy
        end
      end

      context 'when clock_out_time is nil' do
        let(:sleep_record) { build(:sleep_record, user: user, clock_out_time: nil) }

        it 'returns false' do
          expect(sleep_record.clocked_out?).to be_falsey
        end
      end
    end

    describe '#duration_in_hours' do
      context 'when clocked out' do
        let(:sleep_record) { build(:sleep_record, :with_duration, user: user) }

        it 'returns duration in hours' do
          expect(sleep_record.duration_in_hours).to eq(2.0) # 7200 seconds / 3600
        end
      end

      context 'when not clocked out' do
        let(:sleep_record) { build(:sleep_record, user: user, clock_out_time: nil) }

        it 'returns nil' do
          expect(sleep_record.duration_in_hours).to be_nil
        end
      end
    end

    describe '#duration_in_minutes' do
      context 'when clocked out' do
        let(:sleep_record) { build(:sleep_record, :with_duration, user: user) }

        it 'returns duration in minutes' do
          expect(sleep_record.duration_in_minutes).to eq(120.0) # 7200 seconds / 60
        end
      end

      context 'when not clocked out' do
        let(:sleep_record) { build(:sleep_record, user: user, clock_out_time: nil) }

        it 'returns nil' do
          expect(sleep_record.duration_in_minutes).to be_nil
        end
      end
    end
  end

  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:sleep_record)).to be_valid
    end

    it 'creates a sleep record with required attributes' do
      sleep_record = create(:sleep_record)
      expect(sleep_record.user).to be_present
      expect(sleep_record.clock_in_time).to be_present
    end
  end

  describe 'factory traits' do
    describe ':clocked_out' do
      it 'creates a clocked out sleep record' do
        sleep_record = create(:sleep_record, :clocked_out)
        expect(sleep_record.clocked_out?).to be_truthy
        expect(sleep_record.duration).to eq(3600)
      end
    end

    describe ':with_duration' do
      it 'creates a sleep record with duration' do
        sleep_record = create(:sleep_record, :with_duration)
        expect(sleep_record.duration).to eq(7200)
        expect(sleep_record.clocked_out?).to be_truthy
      end
    end

    describe ':this_week' do
      it 'creates a sleep record from this week' do
        sleep_record = create(:sleep_record, :this_week)
        expect(sleep_record.clock_in_time).to be > 1.week.ago
        expect(sleep_record.clock_in_time).to be < Time.current
      end
    end

    describe ':last_week' do
      it 'creates a sleep record from last week' do
        sleep_record = create(:sleep_record, :last_week)
        expect(sleep_record.clock_in_time).to be < 1.week.ago
      end
    end

    describe ':overlapping' do
      it 'creates a potentially overlapping sleep record' do
        sleep_record = create(:sleep_record, :overlapping)
        expect(sleep_record.clock_out_time).to be_nil
        expect(sleep_record.clock_in_time).to be > 2.hour.ago
      end
    end

    describe ':short_duration' do
      it 'creates a sleep record with short duration' do
        sleep_record = create(:sleep_record, :short_duration)
        expect(sleep_record.duration).to eq(300) # 5 minutes
      end
    end

    describe ':long_duration' do
      it 'creates a sleep record with long duration' do
        sleep_record = create(:sleep_record, :long_duration)
        expect(sleep_record.duration).to eq(43200) # 12 hours
      end
    end
  end


  describe 'sleep record following data' do

    let(:user1) { create(:user) }
    let(:user2) { create(:user) }
  
    let!(:record1) do 
      create(:sleep_record, 
             user: user1, 
             clock_in_time: 3.days.ago, 
             clock_out_time: 3.days.ago + 8.hours)  # duration = 28800
    end
    
    let!(:record2) do 
      create(:sleep_record, 
             user: user2, 
             clock_in_time: 2.days.ago, 
             clock_out_time: 2.days.ago + 6.hours)  # duration = 21600
    end
  
    describe '.paginated_by_users' do
      it 'returns correct records for small following_ids' do
        following_ids = [user1.id, user2.id]
        
        records = described_class.paginated_by_users(following_ids, 1, 2)
        
        expect(records.size).to eq(2)
        expect(records.first.duration).to eq(28800)  # ✅ 8 hours in seconds
        expect(records.second.duration).to eq(21600) # ✅ 6 hours in seconds
      end
  
      it 'paginates correctly' do
        following_ids = [user1.id]
        records = described_class.paginated_by_users(following_ids, 1, 1)
        expect(records.size).to eq(1)
      end
  
      it 'returns empty array for blank ids' do
        expect(described_class.paginated_by_users([], 1, 10)).to eq([])
        expect(described_class.paginated_by_users(nil, 1, 10)).to eq([])
      end
  
      it 'includes user association' do
        following_ids = [user1.id]
        records = described_class.paginated_by_users(following_ids, 1, 10)
        expect(records.first.user).to eq(user1)
      end
    end
  
    describe '.count_by_users' do
      it 'returns correct count' do
        following_ids = [user1.id, user2.id]
        expect(described_class.count_by_users(following_ids)).to eq(2)
      end
  
      it 'returns 0 for blank ids' do
        expect(described_class.count_by_users([])).to eq(0)
        expect(described_class.count_by_users(nil)).to eq(0)
      end
    end
  
    describe '.apply_user_filter' do
      let(:small_ids) { [1, 2, 3] }
      let(:large_ids) { (1..Rails.configuration.sleep_record.normal_following_count+1).to_a }
  
      it 'uses WHERE IN for small arrays' do
        relation = described_class.apply_user_filter(described_class.all, small_ids)
        sql = relation.to_sql
        expect(sql).to include('WHERE "sleep_records"."user_id" IN')
      end
  
      it 'uses JOIN for large arrays' do
        relation = described_class.apply_user_filter(described_class.all, large_ids)
        sql = relation.to_sql
        expect(sql).to include('INNER JOIN (VALUES')
      end
    end

  end
end
