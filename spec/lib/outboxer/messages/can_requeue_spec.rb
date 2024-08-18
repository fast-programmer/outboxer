
require 'spec_helper'

module Outboxer
  RSpec.describe Messages do
    describe '.can_requeue?' do
      let!(:message_1) { create(:outboxer_message, :queued) }
      let!(:message_2) { create(:outboxer_message, :dequeued) }
      let!(:message_3) { create(:outboxer_message, :failed) }
      let!(:message_4) { create(:outboxer_message, :failed) }
      let!(:message_5) { create(:outboxer_message, :publishing) }

      context 'when status is queued' do
        it 'returns true' do
          expect(Messages.can_requeue?(status: Message::Status::QUEUED)).to eq false
        end
      end

      context 'when status is dequeued' do
        it 'returns true' do
          expect(Messages.can_requeue?(status: Message::Status::DEQUEUED)).to eq true
        end
      end

      context 'when status is publishing' do
        it 'returns true' do
          expect(Messages.can_requeue?(status: Message::Status::PUBLISHING)).to eq true
        end
      end

      context 'when status is failed' do
        it 'returns true' do
          expect(Messages.can_requeue?(status: Message::Status::FAILED)).to eq true
        end
      end

      context 'when status is nil' do
        it 'returns false' do
          expect(Messages.can_requeue?(status: nil)).to eq false
        end
      end
    end
  end
end
