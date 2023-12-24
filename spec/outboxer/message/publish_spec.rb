require 'spec_helper'

module Outboxer
  RSpec.describe Message do
    describe '.publish!' do
      context 'when no unpublished message is found' do
        it 'raises NotFound exception' do
          expect do
            Message.publish! { |_outboxer_messageable| }
          end.to raise_error(Message::NotFound)
        end
      end

      context 'when an error occurs during publishing' do
        before(:each) do
          invoice, created_event = Accounting::Invoice.create!
        end

        it 'rescues the exception and marks the message as failed' do
          failed_outboxer_message = nil

          expect do
            Message.publish! do |outboxer_messageable|
              failed_outboxer_message = outboxer_messageable.outboxer_message

              raise StandardError, 'test error'
            end
          end.to raise_error(StandardError)

          # binding.pry

          expect(Models::Message.find(failed_outboxer_message.id).status).to eq('failed')
        end
      end
    end
  end
end
