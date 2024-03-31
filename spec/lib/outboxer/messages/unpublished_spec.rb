require 'spec_helper'

module Outboxer
  RSpec.describe Messages do
    describe '.backlogged!' do
      context 'when there are 2 backlogged messages' do
        let!(:backlogged_messages) do
          [
            create(:outboxer_message, :backlogged, created_at: 2.minutes.ago),
            create(:outboxer_message, :backlogged, created_at: 1.minute.ago)
          ]
        end

        context 'when order asc' do
          context 'when limit is 1' do
            let!(:publishing_messages) { Messages.queue!(limit: 1) }

            it 'returns first backlogged message' do
              expect(publishing_messages.count).to eq(1)

              publishing_message = publishing_messages.first
              expect(publishing_message.status).to eq(Models::Message::Status::PUBLISHING)
            end

            it 'keeps last backlogged message' do
              remaining_messages = Models::Message.where(status: Models::Message::Status::BACKLOGGED)

              expect(remaining_messages.count).to eq(1)

              remaining_message = remaining_messages.last
              expect(remaining_message).to eq(backlogged_messages.last)
            end
          end
        end

        context 'when order desc' do
          context 'when limit is 1' do
            let!(:publishing_messages) { Messages.queue!(limit: 1, order: :desc) }

            it 'returns first backlogged message' do
              expect(publishing_messages.count).to eq(1)

              publishing_message = publishing_messages.last
              expect(publishing_message).to eq(backlogged_messages.last)
            end

            it 'keeps first backlogged message' do
              remaining_messages = Models::Message.where(status: Models::Message::Status::BACKLOGGED)
              expect(remaining_messages.count).to eq(1)

              remaining_message = remaining_messages.first
              expect(remaining_message).to eq(backlogged_messages.first)
            end
          end
        end
      end
    end
  end
end
