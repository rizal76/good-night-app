require 'rails_helper'

RSpec.describe 'Api::V1::FollowingsSleepRecords', type: :request do
  let(:user) { create(:user) }
  let(:followed1) { create(:user, name: 'Friend One') }
  let(:followed2) { create(:user, name: 'Friend Two') }
  let(:not_followed) { create(:user) }

  before do
    user.following << followed1
    user.following << followed2
  end

  def sleep_record_args(user, duration_sec_ago:, clocked_out: true, sleep_length: 7*60*60)
    # Handle both Duration objects and Time objects
    if duration_sec_ago.is_a?(ActiveSupport::Duration)
      # It's a duration like 1.day, 2.hours, etc.
      clock_out_time = Time.current - duration_sec_ago
    else
      # It's already a Time object (like 1.day.ago)
      clock_out_time = duration_sec_ago
    end

    # Handle sleep_length - convert to seconds if it's a Duration
    sleep_length_seconds = if sleep_length.is_a?(ActiveSupport::Duration)
                            sleep_length.to_i
    else
                            sleep_length
    end

    clock_in_time = clock_out_time - sleep_length_seconds.seconds

    attrs = {
      user: user,
      clock_in_time: clock_in_time
    }
    attrs[:clock_out_time] = clock_out_time if clocked_out
    attrs[:duration] = sleep_length_seconds if clocked_out
    attrs
  end

  it 'returns followings sleep records only from last week and sorts by duration desc' do
    # Sleep records for followed users within the last week
    sr1 = create(:sleep_record, sleep_record_args(followed1, duration_sec_ago: 1.day, sleep_length: 9.hours)) # 9 hours
    sr2 = create(:sleep_record, sleep_record_args(followed2, duration_sec_ago: 2.days, sleep_length: 8.hours)) # 8 hours
    sr3 = create(:sleep_record, sleep_record_args(followed1, duration_sec_ago: 3.days, sleep_length: 7.hours)) # 7 hours
    # Old record outside last week
    create(:sleep_record, sleep_record_args(followed2, duration_sec_ago: 2.weeks, sleep_length: 8.hours))
    # Not followed user within last week
    create(:sleep_record, sleep_record_args(not_followed, duration_sec_ago: 2.days, sleep_length: 6.hours))

    get "/api/v1/users/#{user.id}/followings/sleep_records"
    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json['success']).to eq(true)
    expect(json['data']['sleep_records'].size).to eq(3)
    # Sorted by duration desc: sr1(9h), sr2(8h), sr3(7h)
    durations = json['data']['sleep_records'].map { |r| r['duration'] }
    expect(durations).to eq([ 9*60*60, 8*60*60, 7*60*60 ])
    # All are from following users
    user_names = json['data']['sleep_records'].map { |r| r['user_name'] }
    expect(user_names).to all(be_in([ followed1.name, followed2.name ]))
    # Only last week records
    max_created = json['data']['sleep_records'].map { |r| Time.parse(r['clock_in_time']) }.max
    expect(max_created).to be > 1.week.ago
    # JSON structure
    expect(json['data']['sleep_records'].first).to include('id', 'user_id', 'clock_in_time', 'clock_out_time', 'duration', 'created_at', 'updated_at', 'user_name')
  end

  it 'supports pagination params' do
    create_list(:sleep_record, 10, user: followed1, clock_in_time: 1.day.ago, clock_out_time: Time.current, duration: 6*60*60)
    get "/api/v1/users/#{user.id}/followings/sleep_records", params: { page: 2, per_page: 3 }
    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json['data']['pagination']).to include('current_page', 'per_page', 'total_pages', 'total_count')
    expect(json['data']['sleep_records'].size).to eq(3)
  end

  it 'returns empty result if no followings or no recent records' do
    lonely = create(:user)
    get "/api/v1/users/#{lonely.id}/followings/sleep_records"
    expect(response).to have_http_status(:unprocessable_content)
    json = JSON.parse(response.body)
    expect(json['success']).to eq(false)
    expect(json['message']).to eq("Failed to fetch data")
    expect(json['errors']).to include("You don't have any following data")
  end

  it 'returns not found for unknown user' do
    get "/api/v1/users/999999/followings/sleep_records"
    expect(response).to have_http_status(:not_found)
    json = JSON.parse(response.body)
    expect(json['success']).to eq(false)
    expect(json['message']).to eq('User not found')
  end
end
