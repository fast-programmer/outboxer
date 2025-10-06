require "rails_helper"

module Outboxer
  RSpec.describe Message, type: :service do
    describe ".publish" do
      context "without a logger" do
        context "when a queued message exists" do
          let!(:queued_message) do
            Models::Message.create!(
              status: Models::Message::Status::QUEUED,
              messageable_type: "Event",
              messageable_id: "1",
              queued_at: ::Time.now.utc
            )
          end

          it "yields { id: ... } and marks record published when block succeeds" do
            yielded_id = nil

            result = Message.publish do |message|
              yielded_id = message[:id]
              # publish to broker
            end

            expect(yielded_id).to eq(queued_message.id)
            expect(result).to eq({
              id: queued_message.id,
              messageable_type: queued_message.messageable_type,
              messageable_id: queued_message.messageable_id
            })
            expect(queued_message.reload.status)
              .to eq(Models::Message::Status::PUBLISHED)
          end

          it "returns { id: ... } and marks as failed on StandardError" do
            result = Message.publish do |_message|
              raise StandardError, "temporary failure"
            end

            expect(result).to eq({
              id: queued_message.id,
              messageable_type: queued_message.messageable_type,
              messageable_id: queued_message.messageable_id
            })
            expect(queued_message.reload.status)
              .to eq(Models::Message::Status::FAILED)
          end

          it "marks failed and re-raises on fatal Exception" do
            expect do
              Message.publish do |_message|
                raise Exception, "fatal crash" # rubocop:disable Lint/RaiseException
              end
            end.to raise_error(Exception, "fatal crash")

            expect(queued_message.reload.status)
              .to eq(Models::Message::Status::FAILED)
          end
        end

        context "when no queued messages exist" do
          it "returns nil" do
            result = Message.publish { raise "block should not be called" }

            expect(result).to be_nil
            expect(
              Models::Message.where(status: Models::Message::Status::QUEUED).count
            ).to eq(0)
          end
        end
      end

      context "with a logger" do
        let(:logger) { instance_double(Logger, info: nil, error: nil, fatal: nil) }

        context "when a queued message exists" do
          let!(:queued_message) do
            Models::Message.create!(
              status: Models::Message::Status::QUEUED,
              messageable_type: "Event",
              messageable_id: "1",
              queued_at: ::Time.now.utc
            )
          end

          it "logs the 'publishing' line" do
            Message.publish(logger: logger) { |_message| } # rubocop:disable Lint/EmptyBlock

            expect(logger).to have_received(:info).with(
              a_string_matching(/Outboxer message publishing id=\d+/)
            )
          end

          it "logs 'publishing failed' on StandardError" do
            Message.publish(logger: logger) do |_message|
              raise StandardError, "temporary failure"
            end

            expect(logger).to have_received(:error).with(
              a_string_matching(/Outboxer message publishing failed id=\d+/)
            )
          end

          it "logs 'fatal' on fatal Exception and re-raises" do
            expect do
              Message.publish(logger: logger) do |_message|
                raise Exception, "fatal crash" # rubocop:disable Lint/RaiseException
              end
            end.to raise_error(Exception, "fatal crash")

            expect(logger).to have_received(:fatal).with(
              a_string_matching(/Outboxer message publishing failed id=\d+/)
            )
          end
        end

        context "when no queued messages exist" do
          let!(:queued_message) do
            Models::Message.create!(
              status: Models::Message::Status::PUBLISHED,
              messageable_type: "Event",
              messageable_id: "1",
              queued_at: ::Time.now.utc
            )
          end

          it "returns nil and does not log" do
            result = Message.publish(logger: logger) { raise "should not run" }

            expect(result).to be_nil
            expect(logger).not_to have_received(:info)
            expect(logger).not_to have_received(:error)
            expect(logger).not_to have_received(:fatal)
          end
        end
      end
    end
  end
end
