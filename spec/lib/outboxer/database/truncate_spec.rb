require "rails_helper"

module Outboxer
  RSpec.describe Database, type: :service do
    describe ".truncate" do
      let!(:historic_counter) { create(:outboxer_counter, :historic, queued_count: 1) }
      let!(:thread_counter) { create(:outboxer_counter, :thread, queued_count: 1) }

      before do
        message = Models::Message.create!(
          status: Models::Message::Status::QUEUED,
          messageable_type: "Event",
          messageable_id: "1",
          queued_at: Time.now.utc)

        exception = Models::Exception.create!(message_id: message.id, message_text: "Example error")
        Models::Frame.create!(exception_id: exception.id, text: "frame", index: 0)

        publisher = Models::Publisher.create!(name: "pub-1", settings: {}, metrics: {})
        Models::Signal.create!(publisher_id: publisher.id, name: "SIG1", created_at: Time.now.utc)
      end

      it "removes all records from all tables" do
        Database.truncate

        expect(Models::Message.count).to eq(0)
        expect(Models::Counter.count).to eq(0)
        expect(Models::Exception.count).to eq(0)
        expect(Models::Frame.count).to eq(0)
        expect(Models::Publisher.count).to eq(0)
        expect(Models::Signal.count).to eq(0)
      end

      it "resets auto-increment IDs" do
        Database.truncate

        message = Models::Message.create!(
          status: Models::Message::Status::QUEUED,
          messageable_type: "Event",
          messageable_id: "1",
          queued_at: Time.now.utc
        )

        expect(message.id).to eq(1)
      end
    end
  end
end
