require "spec_helper"

# ActiveRecord::Base.logger = Logger.new($stdout)

RSpec.describe Outboxer::Message do
  describe ".publish!" do
    context "when unpublished event" do
      it "publishes events" do
        published_events = []

        invoice, created_event = Accounting::Invoice.create!

        expect(Models::Event.count).to eq(1)
        expect(Outboxer::Models::Message.count).to eq(1)

        Outboxer::Message.publish! do |outboxer_messageable|
          case outboxer_messageable.class.name
          when 'Models::Event'
            EventHandlerWorker.perform_async({ 'id' => outboxer_messageable.id })

            published_events << outboxer_messageable
          end
        end

        expect(Models::Event.count).to eq(1)
        expect(Outboxer::Models::Message.count).to eq(0)

        expect(published_events.count).to eq(1)
        published_event = published_events.first

        expect(published_event).to eq(created_event)
        expect(published_event.eventable).to eq(invoice)
        expect(published_event.type).to eq('Accounting::Invoice::Created')
        expect(published_event.payload['invoice']['id']).to eq(invoice.id)
      end
    end

    context "when publishing failed" do
      it "updates outboxer message status to failed" do
        _, event = Accounting::Invoice.create!

        expect(Models::Event.count).to eq(1)
        expect(Outboxer::Models::Message.count).to eq(1)

        begin
          Outboxer::Message.publish! do |_outboxer_messageable|
            raise StandardError, "dummy error"
          end
        rescue => exception
          # no op
        end

        expect(Models::Event.count).to eq(1)
        expect(Outboxer::Models::Message.count).to eq(1)

        outboxer_message = Outboxer::Models::Message.find_by!(outboxer_messageable: event)
        expect(outboxer_message.status).to eq(Outboxer::Models::Message::STATUS[:failed])
        expect(outboxer_message.outboxer_exceptions.count).to eq(1)

        last_outboxer_exception = outboxer_message.outboxer_exceptions.last

        expect(last_outboxer_exception.outboxer_message).to eq(outboxer_message)
        expect(last_outboxer_exception.message_text).to eq("dummy error")
        expect(last_outboxer_exception.class_name).to eq("StandardError")
        expect(last_outboxer_exception.backtrace[1]).to include("lib/outboxer/message.rb")
        expect(last_outboxer_exception.created_at).not_to be_nil
      end

      it "can be republished" do
        Accounting::Invoice.create!

        begin
          Outboxer::Message.publish! do |_event|
            raise StandardError, "dummy error"
          end
        rescue => exception
          # no op
        end

        failed_outboxer_messages = Outboxer::Models::Message
          .where(status: Outboxer::Models::Message::STATUS[:failed])

        expect(failed_outboxer_messages.count).to eq(1)
        failed_outboxer_message = failed_outboxer_messages.first

        Outboxer::Message.republish!(id: failed_outboxer_message.id)

        expect(
          Outboxer::Models::Message
            .where(
              id: failed_outboxer_message.id,
              status: Outboxer::Models::Message::STATUS[:unpublished])
            .count
        ).to eq(1)
      end
    end
  end
end
