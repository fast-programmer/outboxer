require "rails_helper"

module Outboxer
  RSpec.describe Publisher do
    let(:publisher_id) { 1 }
    let(:publisher_name) { "test" }

    describe ".update_messages_by_ids" do
      context "when messages transition from publishing" do
        let!(:message_to_mark_failed) { create(:outboxer_message, :publishing) }
        let!(:message_to_mark_published) { create(:outboxer_message, :publishing) }

        let(:backtrace) do
          ["a.rb:1:in `a'", "b.rb:2:in `b'", "c.rb:3:in `c'"]
        end

        let(:failed_messages) do
          [{
            id: message_to_mark_failed.id,
            exception: {
              class_name: "Sidekiq::ClientError",
              message_text: "Job not enqueued (blocked by client middleware)",
              backtrace: backtrace
            }
          }]
        end

        before do
          Publisher.update_messages_by_ids(
            publisher_id: publisher_id,
            publisher_name: publisher_name,
            published_message_ids: [message_to_mark_published.id],
            failed_messages: failed_messages,
            time: Time
          )
        end

        it "marks the published message as published" do
          expect(Models::Message.published.pluck(:id))
            .to eq([message_to_mark_published.id])
        end

        it "marks the failed message as failed" do
          expect(Models::Message.failed.pluck(:id))
            .to eq([message_to_mark_failed.id])
        end

        it "writes the exception row for the failed message" do
          exception = Models::Exception.find_by(message_id: message_to_mark_failed.id)

          expect(exception).to be_present
          expect(exception.class_name).to eq("Sidekiq::ClientError")
          expect(exception.message_text)
            .to eq("Job not enqueued (blocked by client middleware)")
        end

        it "writes frames in order for the backtrace" do
          exception = Models::Exception.find_by(message_id: message_to_mark_failed.id)

          expect(exception.frames.count).to eq(backtrace.size)
          expect(exception.frames.order(:index).pluck(:text))
            .to eq(backtrace)
          expect(exception.frames.order(:index).pluck(:index))
            .to eq([0, 1, 2])
        end
      end

      context "when exception has no backtrace" do
        let!(:message_to_mark_failed) { create(:outboxer_message, :publishing) }

        it "creates exception without frames" do
          Publisher.update_messages_by_ids(
            publisher_id: publisher_id,
            publisher_name: publisher_name,
            failed_messages: [{
              id: message_to_mark_failed.id,
              exception: { class_name: "RuntimeError", message_text: "oops" }
            }],
            time: Time
          )

          exception = Models::Exception.find_by(message_id: message_to_mark_failed.id)

          expect(exception).to be_present
          expect(exception.frames).to be_empty
        end
      end
    end
  end
end
