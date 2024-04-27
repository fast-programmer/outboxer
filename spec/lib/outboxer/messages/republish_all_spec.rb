require 'spec_helper'

module Outboxer
  RSpec.describe Messages do
    describe '.republish_all' do
      let!(:message_1) { create(:outboxer_message, :backlogged) }
      let!(:message_2) { create(:outboxer_message, :queued) }
      let!(:message_3) { create(:outboxer_message, :failed) }
      let!(:message_4) { create(:outboxer_message, :failed) }
      let!(:message_5) { create(:outboxer_message, :publishing) }

      context 'when status is failed' do
        before do
          Messages.republish_all(status: Message::Status::FAILED, batch_size: 1)
        end

        it 'sets failed messages to backlogged' do
          expect(
            Models::Message.where(status: Message::Status::BACKLOGGED).pluck(:id)
          ).to match_array([message_1.id, message_3.id, message_4.id])
        end
      end

      context 'when status is queued' do
        before do
          Messages.republish_all(status: Message::Status::QUEUED, batch_size: 1)
        end

        it 'sets queued messages to backlogged' do
          expect(
            Models::Message.where(status: Message::Status::BACKLOGGED).pluck(:id)
          ).to match_array([message_1.id, message_2.id])
        end
      end

      context 'when status is publishing' do
        before do
          Messages.republish_all(status: Message::Status::PUBLISHING, batch_size: 1)
        end

        it 'sets publishing messages to backlogged' do
          expect(
            Models::Message.where(status: Message::Status::BACKLOGGED).pluck(:id)
          ).to match_array([message_1.id, message_5.id])
        end
      end

      context 'when status is nil' do
        it 'raises ArgumentError with message' do
          expect do
            Messages.republish_all(status: nil, batch_size: 1)
          end.to raise_error(ArgumentError, "Status must be one of queued, publishing, failed")
        end
      end
    end
  end
end
