require 'rails_helper'

RSpec.describe Follow, type: :model do
  describe 'associations' do
    it { should belong_to(:follower).class_name('User') }
    it { should belong_to(:followed).class_name('User') }
  end

  describe 'validations' do
    it { should validate_presence_of(:follower_id) }
    it { should validate_presence_of(:followed_id) }

    describe 'custom validations' do
      describe 'cannot_follow_self' do
        let(:user) { create(:user) }

        context 'when follower and followed are the same user' do
          let(:follow) { build(:follow, follower: user, followed: user) }

          it 'is invalid' do
            expect(follow).not_to be_valid
            expect(follow.errors[:followed_id]).to include('cannot follow yourself')
          end
        end

        context 'when follower and followed are different users' do
          let(:follower) { create(:user) }
          let(:followed) { create(:user) }
          let(:follow) { build(:follow, follower: follower, followed: followed) }

          it 'is valid' do
            expect(follow).to be_valid
          end
        end
      end
    end
  end

  describe 'uniqueness validation' do
    let(:follower) { create(:user) }
    let(:followed) { create(:user) }

    context 'when trying to create duplicate follow' do
      before { create(:follow, follower: follower, followed: followed) }

      it 'prevents duplicate follows' do
        duplicate_follow = build(:follow, follower: follower, followed: followed)
        expect(duplicate_follow).not_to be_valid
        expect(duplicate_follow.errors[:follower_id]).to include('is already following this user')
      end
    end

    context 'when different users follow the same person' do
      let(:another_follower) { create(:user) }

      before { create(:follow, follower: follower, followed: followed) }

      it 'allows different followers to follow the same person' do
        different_follow = build(:follow, follower: another_follower, followed: followed)
        expect(different_follow).to be_valid
      end
    end

    context 'when same user follows different people' do
      let(:another_followed) { create(:user) }

      before { create(:follow, follower: follower, followed: followed) }

      it 'allows same follower to follow different people' do
        different_follow = build(:follow, follower: follower, followed: another_followed)
        expect(different_follow).to be_valid
      end
    end
  end

  describe 'factory' do
    it 'creates a follow with different users' do
      follow = create(:follow)
      expect(follow.follower).to be_present
      expect(follow.followed).to be_present
      expect(follow.follower).not_to eq(follow.followed)
    end
  end

  describe 'factory traits' do
    describe ':with_different_users' do
      it 'creates a follow with custom user names' do
        follow = create(:follow, :with_different_users,
                       follower_name: 'Alice',
                       followed_name: 'Bob')

        expect(follow.follower.name).to eq('Alice')
        expect(follow.followed.name).to eq('Bob')
      end
    end

    describe ':self_follow' do
      it 'creates a follow where user follows themselves' do
        follow = build(:follow, :self_follow)
        expect(follow.follower).to eq(follow.followed)
      end

      it 'is invalid due to custom validation' do
        follow = build(:follow, :self_follow)
        expect(follow).not_to be_valid
        expect(follow.errors[:followed_id]).to include('cannot follow yourself')
      end
    end
  end

  describe 'database constraints' do
    let(:follower) { create(:user) }
    let(:followed) { create(:user) }

    it 'enforces unique constraint on follower_id and followed_id' do
      create(:follow, follower: follower, followed: followed)

      expect {
        Follow.create!(follower: follower, followed: followed)
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe 'foreign key constraints' do
    it 'prevents creating follow with non-existent follower' do
      follow = build(:follow, follower_id: 999999)
      expect { follow.save! }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'prevents creating follow with non-existent followed user' do
      follow = build(:follow, followed_id: 999999)
      expect { follow.save! }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe 'cascading deletes' do
    let(:follower) { create(:user) }
    let(:followed) { create(:user) }
    let!(:follow) { create(:follow, follower: follower, followed: followed) }

    it 'deletes follow when follower is deleted' do
      expect { follower.destroy }.to change { Follow.count }.by(-1)
    end

    it 'deletes follow when followed user is deleted' do
      expect { followed.destroy }.to change { Follow.count }.by(-1)
    end
  end
end
