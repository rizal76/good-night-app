require 'rails_helper'

RSpec.describe 'Api::V1::Follows', type: :request do
  let(:follower) { create(:user, name: 'Follower User') }
  let(:followed) { create(:user, name: 'Followed User') }
  let(:other)    { create(:user, name: 'Other User') }

  describe 'POST /api/v1/users/:user_id/follows' do
    it 'follows another user successfully' do
      post "/api/v1/users/#{follower.id}/follows", params: { followed_id: followed.id }
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['success']).to eq(true)
      expect(json['message']).to eq('Successfully followed')
      expect(json['data']['follower_id']).to eq(follower.id)
      expect(json['data']['followed_id']).to eq(followed.id)
    end

    it 'does not allow following the same user twice' do
      post "/api/v1/users/#{follower.id}/follows", params: { followed_id: followed.id }
      post "/api/v1/users/#{follower.id}/follows", params: { followed_id: followed.id }
      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json['success']).to eq(false)
      expect(json['errors']).to include('Follower is already following this user')
    end

    it 'does not allow following yourself' do
      post "/api/v1/users/#{follower.id}/follows", params: { followed_id: follower.id }
      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json['errors']).to include('Followed cannot follow yourself')
    end

    it 'returns not found error if follower does not exist' do
      post "/api/v1/users/9999/follows", params: { followed_id: followed.id }
      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json['success']).to eq(false)
      expect(json['message']).to eq('User not found')
      expect(json['errors']).to include('User with the given ID does not exist')
    end

    it 'returns error if followed user does not exist' do
      post "/api/v1/users/#{follower.id}/follows", params: { followed_id: 9999 }
      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json['errors']).to include('Followed Followed user not found')
    end
  end

  describe 'DELETE /api/v1/users/:user_id/follows/:id' do
    before { post "/api/v1/users/#{follower.id}/follows", params: { followed_id: followed.id } }

    it 'unfollows a user successfully' do
      delete "/api/v1/users/#{follower.id}/follows/#{followed.id}"
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to eq(true)
      expect(json['message']).to eq('Successfully unfollowed')
    end

    it 'returns error if trying to unfollow a user not being followed' do
      delete "/api/v1/users/#{follower.id}/follows/#{other.id}"
      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json['success']).to eq(false)
      expect(json['errors']).to include('Not following this user')
    end

    it 'returns not found if follower does not exist for unfollow' do
      delete "/api/v1/users/9999/follows/#{followed.id}"
      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json['success']).to eq(false)
      expect(json['message']).to eq('User not found')
    end
  end
end
