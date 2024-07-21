require "spec_helper"

module Outboxer
  RSpec.describe Message do
    describe ".queue" do
      context "when messageable argument provided" do
        let(:event) { double("Event", id: "1", class: double(name: "Event")) }

        let!(:queued_message) { Message.queue(messageable: event) }

        it "creates model with queued status" do
          expect(queued_message[:id]).to eq(
            Models::Message.where(status: Models::Message::Status::QUEUED).first.id)
        end
      end

      context "when messageable_type and messageable_id arguments provided" do
        let!(:queued_message) do
          Message.queue(messageable_type: "Event", messageable_id: "1")
        end

        it "creates model with queued status" do
          expect(queued_message[:id]).to eq(
            Models::Message.where(status: Models::Message::Status::QUEUED).first.id)
        end
      end
    end
  end
end
