require 'rails_helper'

module Outboxer
  RSpec.describe Messages do
    describe '.list' do
      let!(:messages) do
        create(:outboxer_message, :publishing, created_at: 2.days.ago)
        create(:outboxer_message, :publishing, created_at: 2.days.ago)
        create(:outboxer_message, :unpublished, created_at: 1.day.ago)
        create(:outboxer_message, :failed)
      end

      it 'returns all publishing messages' do
        result = Messages.list
        expect(result.size).to eq(4)
      end
    end
  end
end
