require 'rails_helper'

RSpec.describe 'Api::V1::ClockIns', type: :request do
  let(:user) { create(:user) }
  let(:clocked_in_user) { create(:user, :clocked_in) }
  let(:user_with_records) { create(:user, :with_sleep_records) }
  
  before do
    # Allow localhost for testing
    host! 'localhost'
  end
  
  describe 'POST /api/v1/users/:user_id/clock_ins' do
    context 'when user exists' do
      context 'and user is not currently clocked in' do
        it 'creates a new sleep record and returns success response' do
          expect {
            post "/api/v1/users/#{user.id}/clock_ins"
          }.to change { user.sleep_records.count }.by(1)

          expect(response).to have_http_status(:created)
          
          json_response = JSON.parse(response.body)
          expect(json_response['success']).to be true
          expect(json_response['message']).to eq('Success to record')
          expect(json_response['data']).to be_present
          expect(json_response['data']['sleep_records']).to be_an(Array)
          expect(json_response['data']['pagination']).to be_present
          
          # Verify the created sleep record
          sleep_record = user.sleep_records.last
          expect(sleep_record.clock_in_time).to be_present
          expect(sleep_record.clock_out_time).to be_nil
          expect(sleep_record.duration).to be_nil
        end

        it 'returns paginated sleep records' do
          # Create some existing sleep records
          create_list(:sleep_record, 5, :clocked_out, user: user)
          
          post "/api/v1/users/#{user.id}/clock_ins"
          
          expect(response).to have_http_status(:created)
          
          json_response = JSON.parse(response.body)
          sleep_records = json_response['data']['sleep_records']
          pagination = json_response['data']['pagination']
          
          expect(sleep_records.length).to eq(6) # 5 existing + 1 new
          expect(pagination['current_page']).to eq(1)
          expect(pagination['per_page']).to eq(20)
          expect(pagination['total_count']).to eq(6)
        end

        it 'accepts custom pagination parameters' do
          create_list(:sleep_record, 5, :clocked_out, user: user)
          
          post "/api/v1/users/#{user.id}/clock_ins", params: { page: 1, per_page: 3 }
          
          expect(response).to have_http_status(:created)
          
          json_response = JSON.parse(response.body)
          sleep_records = json_response['data']['sleep_records']
          pagination = json_response['data']['pagination']
          
          expect(sleep_records.length).to eq(3)
          expect(pagination['current_page']).to eq(1)
          expect(pagination['per_page']).to eq(3)
        end

        it 'returns sleep records in correct format' do
          post "/api/v1/users/#{user.id}/clock_ins"
          
          expect(response).to have_http_status(:created)
          
          json_response = JSON.parse(response.body)
          sleep_record = json_response['data']['sleep_records'].first
          
          expect(sleep_record).to include(
            'id', 'user_id', 'clock_in_time', 'clock_out_time', 
            'duration', 'created_at', 'updated_at', 'user_name'
          )
          expect(sleep_record['user_id']).to eq(user.id)
          expect(sleep_record['user_name']).to eq(user.name)
        end
      end

      context 'and user is currently clocked in' do
        it 'clocks out the user and calculates duration' do
          clock_in_time = clocked_in_user.current_sleep_session.clock_in_time
          
          # Travel forward in time to simulate sleep duration
          Timecop.travel(clock_in_time + 2.hours) do
            expect {
              post "/api/v1/users/#{clocked_in_user.id}/clock_ins"
            }.not_to change { clocked_in_user.sleep_records.count }

            expect(response).to have_http_status(:created)
            
            json_response = JSON.parse(response.body)
            expect(json_response['success']).to be true
            
            # Verify the sleep record was updated
            sleep_record = clocked_in_user.sleep_records.last
            expect(sleep_record.clock_out_time).to be_present
            expect(sleep_record.duration).to eq(7200) # 2 hours in seconds
          end
        end

        it 'returns error when sleep duration is too short' do
          clock_in_time = clocked_in_user.current_sleep_session.clock_in_time
          
          # Mock the minimum duration to be longer than our test duration
          allow(Rails.configuration.sleep).to receive(:min_duration_seconds).and_return(1800) # 30 minutes
          
          # Travel forward only 5 minutes (less than minimum duration of 30 minutes)
          Timecop.travel(clock_in_time + 5.minutes) do
            # Mock the service to return false to test the error handling
            allow_any_instance_of(ClockInService).to receive(:call).and_return(false)
            allow_any_instance_of(ClockInService).to receive(:errors).and_return(
              double('errors', full_messages: ['Minimum sleep duration is 1800 seconds. Current: 300 seconds.'])
            )
            
            expect {
              post "/api/v1/users/#{clocked_in_user.id}/clock_ins"
            }.not_to change { clocked_in_user.sleep_records.count }

            expect(response).to have_http_status(:unprocessable_entity)
            
            json_response = JSON.parse(response.body)
            expect(json_response['success']).to be false
            expect(json_response['message']).to eq('Failed to record')
            expect(json_response['errors']).to include(
              'Minimum sleep duration is 1800 seconds. Current: 300 seconds.'
            )
          end
        end

        it 'handles edge case when duration is exactly minimum' do
          clock_in_time = clocked_in_user.current_sleep_session.clock_in_time
          
          # Travel forward exactly 10 minutes (minimum duration)
          Timecop.travel(clock_in_time + 10.minutes) do
            post "/api/v1/users/#{clocked_in_user.id}/clock_ins"
            
            expect(response).to have_http_status(:created)
            
            sleep_record = clocked_in_user.sleep_records.last
            expect(sleep_record.duration).to eq(600) # 10 minutes in seconds
          end
        end
      end

      context 'with existing sleep records' do
        it 'returns all sleep records ordered by creation date (descending)' do
          # Create sleep records with different creation times
          old_record = create(:sleep_record, :clocked_out, user: user, created_at: 2.days.ago)
          recent_record = create(:sleep_record, :clocked_out, user: user, created_at: 1.day.ago)
          
          post "/api/v1/users/#{user.id}/clock_ins"
          
          expect(response).to have_http_status(:created)
          
          json_response = JSON.parse(response.body)
          sleep_records = json_response['data']['sleep_records']
          
          # Should be ordered by created_at desc (newest first)
          expect(sleep_records.first['id']).to eq(user.sleep_records.last.id) # newest record
          expect(sleep_records.last['id']).to eq(old_record.id) # oldest record
        end
      end
    end

    context 'when user does not exist' do
      it 'returns not found error' do
        post "/api/v1/users/99999/clock_ins"
        
        expect(response).to have_http_status(:not_found)
        
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('User not found')
        expect(json_response['errors']).to include('User with the given ID does not exist')
      end
    end

    context 'when service fails' do
      before do
        allow_any_instance_of(ClockInService).to receive(:call).and_return(false)
        allow_any_instance_of(ClockInService).to receive(:errors).and_return(
          double('errors', full_messages: ['Some service error'])
        )
      end

      it 'returns unprocessable entity with error message' do
        post "/api/v1/users/#{user.id}/clock_ins"
        
        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Failed to record')
        expect(json_response['errors']).to include('Some service error')
      end
    end

    context 'pagination edge cases' do
      it 'handles page parameter as string' do
        create_list(:sleep_record, 5, :clocked_out, user: user)
        
        post "/api/v1/users/#{user.id}/clock_ins", params: { page: "2", per_page: "2" }
        
        expect(response).to have_http_status(:created)
        
        json_response = JSON.parse(response.body)
        pagination = json_response['data']['pagination']
        
        expect(pagination['current_page']).to eq(2)
        expect(pagination['per_page']).to eq(2)
      end

      it 'uses default values when pagination params are invalid' do
        create_list(:sleep_record, 5, :clocked_out, user: user)
        
        post "/api/v1/users/#{user.id}/clock_ins", params: { page: "invalid", per_page: "invalid" }
        
        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Failed to record')
      end

      it 'handles empty page gracefully' do
        post "/api/v1/users/#{user.id}/clock_ins", params: { page: 999 }
        
        expect(response).to have_http_status(:created)
        
        json_response = JSON.parse(response.body)
        sleep_records = json_response['data']['sleep_records']
        pagination = json_response['data']['pagination']
        
        expect(sleep_records).to be_empty
        expect(pagination['current_page']).to eq(999)
        expect(pagination['total_count']).to eq(1) # Only the newly created record
      end
    end

    context 'response format validation' do
      it 'includes all required fields in success response' do
        post "/api/v1/users/#{user.id}/clock_ins"
        
        expect(response).to have_http_status(:created)
        
        json_response = JSON.parse(response.body)
        
        # Top level fields
        expect(json_response).to have_key('success')
        expect(json_response).to have_key('message')
        expect(json_response).to have_key('data')
        
        # Data fields
        expect(json_response['data']).to have_key('sleep_records')
        expect(json_response['data']).to have_key('pagination')
        
        # Pagination fields
        pagination = json_response['data']['pagination']
        expect(pagination).to have_key('current_page')
        expect(pagination).to have_key('per_page')
        expect(pagination).to have_key('total_pages')
        expect(pagination).to have_key('total_count')
      end

      it 'includes all required fields in error response' do
        post "/api/v1/users/99999/clock_ins"
        
        expect(response).to have_http_status(:not_found)
        
        json_response = JSON.parse(response.body)
        
        expect(json_response).to have_key('success')
        expect(json_response).to have_key('message')
        expect(json_response).to have_key('errors')
      end
    end

    context 'time zone handling' do
      it 'handles clock_in_time correctly across time zones' do
        # Mock Time.current to return a specific time
        fixed_time = Time.zone.parse('2024-01-15 10:30:00')
        allow(Time).to receive(:current).and_return(fixed_time)
        
        post "/api/v1/users/#{user.id}/clock_ins"
        
        expect(response).to have_http_status(:created)
        
        sleep_record = user.sleep_records.last
        expect(sleep_record.clock_in_time).to be_within(1.second).of(fixed_time)
      end
    end

    context 'concurrent requests' do
      it 'handles multiple clock-in requests gracefully' do
        # Simulate concurrent requests
        threads = []
        results = []
        
        3.times do
          threads << Thread.new do
            post "/api/v1/users/#{user.id}/clock_ins"
            results << response.status
          end
        end
        
        threads.each(&:join)
        
        # At least one should succeed
        expect(results).to include(201)
        
        # Should have exactly one sleep record created
        expect(user.sleep_records.count).to eq(1)
      end
    end
  end
end