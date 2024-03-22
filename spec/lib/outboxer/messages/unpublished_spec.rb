require 'spec_helper'

module Outboxer
  RSpec.describe Messages do
    describe '.unpublished!' do
      context 'when there are 2 unpublished messages' do
        let!(:unpublished_messages) do
          [
            create(:outboxer_message, :unpublished, created_at: 2.minutes.ago),
            create(:outboxer_message, :unpublished, created_at: 1.minute.ago)
          ]
        end

        context 'when order asc' do
          context 'when limit is 1' do
            let!(:publishing_messages) { Messages.unpublished!(limit: 1) }

            it 'returns first unpublished message' do
              expect(publishing_messages.count).to eq(1)

              publishing_message = publishing_messages.first
              expect(publishing_message.status).to eq(Models::Message::Status::PUBLISHING)
            end

            it 'keeps last unpublished message' do
              remaining_messages = Models::Message.where(status: Models::Message::Status::UNPUBLISHED)

              expect(remaining_messages.count).to eq(1)

              remaining_message = remaining_messages.last
              expect(remaining_message).to eq(unpublished_messages.last)
            end
          end
        end

        context 'when order desc' do
          context 'when limit is 1' do
            let!(:publishing_messages) { Messages.unpublished!(limit: 1, order: :desc) }

            it 'returns first unpublished message' do
              expect(publishing_messages.count).to eq(1)

              publishing_message = publishing_messages.last
              expect(publishing_message).to eq(unpublished_messages.last)
            end

            it 'keeps first unpublished message' do
              remaining_messages = Models::Message.where(status: Models::Message::Status::UNPUBLISHED)
              expect(remaining_messages.count).to eq(1)

              remaining_message = remaining_messages.first
              expect(remaining_message).to eq(unpublished_messages.first)
            end
          end
        end
      end
    end
  end
end
