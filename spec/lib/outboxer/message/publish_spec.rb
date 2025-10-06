require "spec_helper"

module Outboxer
  RSpec.describe Message, type: :service do
    describe ".publish" do
      let!(:queued_message) { Models::Message.create!(status: "queued") }

      it "returns the claimed message and marks as published when block succeeds" do
        result = Message.publish do |message|
          expect(message.id).to eq(queued_message.id)

          # publish to broker
        end

        expect(result).to be_a(Models::Message)
        expect(result.id).to eq(queued_message.id)
        expect(queued_message.reload.status).to eq("published")
      end

      it "returns the claimed message and marks as publishing_failed on StandardError" do
        result = Message.publish do |_message|
          raise StandardError, "temporary failure"
        end

        expect(result).to be_a(Models::Message)
        expect(result.id).to eq(queued_message.id)
        expect(queued_message.reload.status).to eq("publishing_failed")
      end

      it "marks failed and re-raises on fatal Exception" do
        expect do
          Message.publish do |_message|
            raise Exception, "fatal crash"
          end
        end.to raise_error(Exception, "fatal crash")

        expect(queued_message.reload.status).to eq("publishing_failed")
      end

      it "returns nil when there are no queued messages" do
        queued_message.update!(status: "published")

        result = Message.publish { raise "block should not be called" }

        expect(result).to be_nil
        expect(Models::Message.where(status: "queued").count).to eq(0)
      end
    end
  end
end
