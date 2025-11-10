require "rails_helper"

module Outboxer
  module Models
    class Message
      RSpec.describe Counter, type: :model do
        describe ".increment_counts_by" do
          let(:hostname)   { Socket.gethostname }
          let(:process_id) { Process.pid }
          let(:thread_id)  { Thread.current.object_id }

          before { create(:outboxer_message_counter, :thread) }

          it "increments existing counts" do
            Counter.increment_counts_by(
              hostname: hostname,
              process_id: process_id,
              thread_id: thread_id,
              queued_delta: 1
            )

            Counter.increment_counts_by(
              hostname: hostname,
              process_id: process_id,
              thread_id: thread_id,
              queued_delta: 2
            )

            row = Counter.find_by(
              hostname: hostname,
              process_id: process_id,
              thread_id: thread_id
            )

            expect(row.queued_count).to eq(3)
          end

          it "updates multiple counts atomically" do
            Counter.increment_counts_by(
              hostname: hostname,
              process_id: process_id,
              thread_id: thread_id,
              publishing_delta: 1,
              published_delta: 2,
              failed_delta: 3
            )

            row = Counter.find_by(
              hostname: hostname,
              process_id: process_id,
              thread_id: thread_id
            )

            expect(row.publishing_count).to eq(1)
            expect(row.published_count).to eq(2)
            expect(row.failed_count).to eq(3)
          end

          it "does not create duplicate rows on repeated calls" do
            3.times do
              Counter.increment_counts_by(
                hostname: hostname,
                process_id: process_id,
                thread_id: thread_id,
                queued_delta: 1
              )
            end

            count = Counter.where(
              hostname: hostname,
              process_id: process_id,
              thread_id: thread_id
            ).count

            expect(count).to eq(1)
          end
        end
      end
    end
  end
end
