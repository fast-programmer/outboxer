require 'spec_helper'

module Outboxer
  RSpec.describe Message do
    describe '.republish' do
      context 'when failed message' do
        let!(:failed_message) { create(:outboxer_message, :failed) }

        let!(:backlogged_message) { Message.republish(id: failed_message.id) }

        it 'returns backlogged message' do
          expect(backlogged_message[:id]).to eq(failed_message.id)
        end

        it 'updates failed message status to backlogged' do
          failed_message.reload

          expect(failed_message.status).to eq(Models::Message::Status::BACKLOGGED)
        end
      end

      context 'when backlogged messaged' do
        let(:backlogged_message) { create(:outboxer_message, :backlogged) }
        let!(:updated_at) { backlogged_message.updated_at }

        it 'modifies updated_at' do
          Message.republish(id: backlogged_message.id)

          backlogged_message.reload

          expect(backlogged_message.status).to eq(Models::Message::Status::BACKLOGGED)
          expect(backlogged_message.updated_at).to be > updated_at
        end

        it 'does not delete backlogged message' do
          begin
            Message.published(id: backlogged_message.id)
          rescue InvalidTransition
            # ignore
          end

          expect(Models::Message.count).to eq(1)
          expect(Models::Message.first).to eq(backlogged_message)
        end
      end
    end
  end
end
