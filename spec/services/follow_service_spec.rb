require 'rails_helper'

RSpec.describe FollowService, type: :model do
  let(:follower) { create(:user) }
  let(:followed) { create(:user) }
  let(:valid_attributes) { { follower_id: follower.id, followed_id: followed.id } }

  describe 'attributes' do
    it 'has follower_id attribute' do
      service = described_class.new(follower_id: 1)
      expect(service.follower_id).to eq(1)
    end

    it 'has followed_id attribute' do
      service = described_class.new(followed_id: 2)
      expect(service.followed_id).to eq(2)
    end
  end

  describe 'validations' do
    subject { described_class.new(valid_attributes) }

    it 'validates presence of follower_id' do
      subject.follower_id = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:follower_id]).to include("can't be blank")
    end

    it 'validates presence of followed_id' do
      subject.followed_id = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:followed_id]).to include("can't be blank")
    end

    describe 'follower_and_followed_are_different' do
      context 'when follower and followed are the same' do
        subject { described_class.new(follower_id: follower.id, followed_id: follower.id) }

        it 'is invalid' do
          expect(subject).not_to be_valid
          expect(subject.errors[:followed_id]).to include('cannot follow yourself')
        end
      end

      context 'when follower and followed are different' do
        it 'is valid' do
          expect(subject).to be_valid
        end
      end
    end

    describe 'follower_exists' do
      context 'when follower does not exist' do
        subject { described_class.new(follower_id: 9999, followed_id: followed.id) }

        it 'is invalid' do
          expect(subject).not_to be_valid
          expect(subject.errors[:follower_id]).to include('Follower user not found')
        end
      end
    end

    describe 'followed_exists' do
      context 'when followed does not exist' do
        subject { described_class.new(follower_id: follower.id, followed_id: 9999) }

        it 'is invalid' do
          expect(subject).not_to be_valid
          expect(subject.errors[:followed_id]).to include('Followed user not found')
        end
      end
    end
  end

  describe '#follow' do
    subject { described_class.new(valid_attributes) }

    context 'with valid attributes' do
      it 'creates a new follow relationship' do
        expect { subject.follow }.to change(Follow, :count).by(1)
      end

      it 'returns the follow object' do
        follow = subject.follow
        expect(follow).to be_a(Follow)
        expect(follow.follower_id).to eq(follower.id)
        expect(follow.followed_id).to eq(followed.id)
      end

      it 'does not have errors' do
        subject.follow
        expect(subject.errors).to be_empty
      end
    end

    context 'with invalid attributes' do
      subject { described_class.new(follower_id: nil, followed_id: nil) }

      it 'does not create a follow relationship' do
        expect { subject.follow }.not_to change(Follow, :count)
      end

      it 'returns nil' do
        expect(subject.follow).to be_nil
      end

      it 'has errors' do
        subject.follow
        expect(subject.errors).not_to be_empty
      end
    end

    context 'when follow save fails' do
      let(:mock_follow) { instance_double(Follow) }
      
      before do
        allow(Follow).to receive(:new).and_return(mock_follow)
        allow(mock_follow).to receive(:save).and_return(false)
        
        # Create a real ActiveModel::Errors object for the mock
        errors_object = ActiveModel::Errors.new(mock_follow)
        errors_object.add(:base, 'Some error')
        allow(mock_follow).to receive(:errors).and_return(errors_object)
      end

      it 'returns nil' do
        expect(subject.follow).to be_nil
      end

      it 'merges follow errors' do
        subject.follow
        expect(subject.errors[:base]).to include('Some error')
      end
    end

    context 'when trying to follow yourself' do
      subject { described_class.new(follower_id: follower.id, followed_id: follower.id) }

      it 'does not create a follow relationship' do
        expect { subject.follow }.not_to change(Follow, :count)
      end

      it 'returns nil' do
        expect(subject.follow).to be_nil
      end

      it 'has appropriate error' do
        subject.follow
        expect(subject.errors[:followed_id]).to include('cannot follow yourself')
      end
    end
  end

  describe '#unfollow' do
    subject { described_class.new(valid_attributes) }

    context 'when following relationship exists' do
      let!(:existing_follow) { create(:follow, follower: follower, followed: followed) }

      it 'destroys the follow relationship' do
        expect { subject.unfollow }.to change(Follow, :count).by(-1)
      end

      it 'returns the destroyed follow object' do
        result = subject.unfollow
        expect(result).to eq(existing_follow)
      end

      it 'does not have errors' do
        subject.unfollow
        expect(subject.errors).to be_empty
      end
    end

    context 'when following relationship does not exist' do
      it 'returns nil' do
        expect(subject.unfollow).to be_nil
      end

      it 'has appropriate error' do
        subject.unfollow
        expect(subject.errors[:base]).to include('Not following this user')
      end
    end

    context 'when follower does not exist' do
      subject { described_class.new(follower_id: 9999, followed_id: followed.id) }

      it 'returns nil' do
        expect(subject.unfollow).to be_nil
      end

      it 'has appropriate error' do
        subject.unfollow
        expect(subject.errors[:follower_id]).to include('Follower user not found')
      end
    end

    context 'when followed does not exist' do
      subject { described_class.new(follower_id: follower.id, followed_id: 9999) }

      it 'returns nil' do
        expect(subject.unfollow).to be_nil
      end

      it 'has appropriate error' do
        subject.unfollow
        expect(subject.errors[:followed_id]).to include('Followed user not found')
      end
    end

    context 'when destroy fails' do
      let!(:existing_follow) { create(:follow, follower: follower, followed: followed) }

      before do
        allow_any_instance_of(Follow).to receive(:destroy).and_return(false)
      end

      it 'returns nil' do
        expect(subject.unfollow).to be_nil
      end

      it 'has appropriate error' do
        subject.unfollow
        expect(subject.errors[:base]).to include('Not following this user')
      end
    end
  end

  describe '#valid_for_unfollow?' do
    subject { described_class.new(valid_attributes) }

    context 'with valid attributes' do
      it 'returns true' do
        expect(subject.send(:valid_for_unfollow?)).to be true
      end

      it 'clears previous errors' do
        subject.errors.add(:base, 'Some error')
        subject.send(:valid_for_unfollow?)
        expect(subject.errors).to be_empty
      end
    end

    context 'with invalid attributes' do
      subject { described_class.new(follower_id: 9999, followed_id: 9999) }

      it 'returns false' do
        expect(subject.send(:valid_for_unfollow?)).to be false
      end

      it 'has errors' do
        subject.send(:valid_for_unfollow?)
        expect(subject.errors).not_to be_empty
      end
    end
  end
end