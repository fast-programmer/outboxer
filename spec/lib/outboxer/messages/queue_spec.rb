require 'spec_helper'

module Outboxer
  RSpec.describe Messages do
    describe '.queue!' do
      context 'when there are 2 backlogged messages' do
        let!(:backlogged_messages) do
          [
            create(:outboxer_message, :backlogged, updated_at: 2.minutes.ago),
            create(:outboxer_message, :backlogged, updated_at: 1.minute.ago)
          ]
        end

        context 'when limit is 1' do
          let!(:queued_messages) { Messages.queue!(limit: 1) }

          it 'returns first backlogged message' do
            expect(queued_messages.count).to eq(1)

            queued_message = queued_messages.first
            expect(queued_message.status).to eq(Models::Message::Status::QUEUED)
          end

          it 'keeps last backlogged message' do
            remaining_messages = Models::Message.where(status: Models::Message::Status::BACKLOGGED)

            expect(remaining_messages.count).to eq(1)

            remaining_message = remaining_messages.last
            expect(remaining_message).to eq(backlogged_messages.last)
          end
        end
      end
    end
  end
end
