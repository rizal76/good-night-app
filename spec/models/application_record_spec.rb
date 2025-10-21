require 'rails_helper'

RSpec.describe ApplicationRecord, type: :model do
  describe 'class methods' do
    describe '.primary_abstract_class' do
      it 'is configured as primary abstract class' do
        expect(ApplicationRecord.primary_abstract_class).to be_truthy
      end
    end
  end

  describe 'inheritance' do
    it 'is an abstract class' do
      expect(ApplicationRecord.abstract_class?).to be_truthy
    end

    it 'inherits from ActiveRecord::Base' do
      expect(ApplicationRecord.superclass).to eq(ActiveRecord::Base)
    end
  end

  describe 'instantiation' do
    it 'cannot be instantiated directly' do
      expect { ApplicationRecord.new }.to raise_error(NotImplementedError)
    end
  end

  describe 'model inheritance' do
    it 'is the base class for User model' do
      expect(User.superclass).to eq(ApplicationRecord)
    end

    it 'is the base class for SleepRecord model' do
      expect(SleepRecord.superclass).to eq(ApplicationRecord)
    end

    it 'is the base class for Follow model' do
      expect(Follow.superclass).to eq(ApplicationRecord)
    end
  end
end
