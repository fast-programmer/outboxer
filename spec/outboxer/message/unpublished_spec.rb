require 'spec_helper'

module Outboxer
  RSpec.describe Message do
    describe '.unpublished!' do
      let!(:invoice) { ::Models::Invoice.create! }
      let(:limit) { 5 }
      let(:unpublished_status) {  }
      let(:publishing_status) { Models::Message::STATUS[:publishing] }

      context 'when there are 10 unpublished messages' do
        before do
          10.times { invoice.events.create!(type: 'Invoice::Created') }
        end

        it 'updates the status of a limited number of messages to publishing' do
          expect(
            Models::Message.where(status: Models::Message::STATUS[:unpublished]).count
          ).to eq(10)

          Message.unpublished!(limit: limit)

          expect(
            Models::Message.where(status: Models::Message::STATUS[:unpublished]).count
          ).to eq(5)
        end

        it 'returns the messages with updated status' do
          messages = Message.unpublished!(limit: limit)

          expect(messages.count).to eq(limit)
          expect(messages).to all(have_attributes(status: publishing_status))
          expect(messages).to match_array(
            Models::Message.where(status: publishing_status).order(created_at: :asc).limit(limit))

          messages.each do |message|
            expect(message.outboxer_messageable).to be_a(::Models::Event)
            expect(message.outboxer_messageable.eventable_type).to eq('Models::Invoice')
            expect(message.outboxer_messageable.type).to eq('Invoice::Created')
          end
        end

        it 'does not update messages beyond the specified limit' do
          Message.unpublished!(limit: limit)

          expect(Models::Message.where(status: unpublished_status).count).to eq(5)
        end
      end

      context 'when there are no unpublished messages' do
        it 'does not update any messages' do
          expect(Models::Message.where(status: publishing_status).count).to eq(0)

          Message.unpublished!(limit: limit)

          expect(Models::Message.where(status: publishing_status).count).to eq(0)
        end

        it 'returns an empty array' do
          expect(Message.unpublished!(limit: limit)).to be_empty
        end
      end
    end
  end
end
