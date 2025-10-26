require "rails_helper"

module Outboxer
  module Models
    RSpec.describe ThreadCounter, type: :model do
      describe ".insert_or_increment" do
        let(:hostname)   { "test-host" }
        let(:process_id) { 12_345 }
        let(:thread_id)  { 999 }
        let(:now)        { Time.now.utc }

        it "inserts a new row successfully" do
          expect do
            ThreadCounter.insert_or_increment(
              hostname: hostname,
              process_id: process_id,
              thread_id: thread_id,
              queued_count: 1,
              time: now
            )
          end.to change(ThreadCounter, :count).by(1)

          row = ThreadCounter.find_by(
            hostname: hostname,
            process_id: process_id,
            thread_id: thread_id
          )

          expect(row).not_to be_nil
          expect(row.queued_count).to eq(1)
        end

        it "increments existing counts if called again" do
          ThreadCounter.insert_or_increment(
            hostname: hostname,
            process_id: process_id,
            thread_id: thread_id,
            queued_count: 1
          )

          ThreadCounter.insert_or_increment(
            hostname: hostname,
            process_id: process_id,
            thread_id: thread_id,
            queued_count: 2
          )

          row = ThreadCounter.find_by(
            hostname: hostname,
            process_id: process_id,
            thread_id: thread_id
          )

          expect(row.queued_count).to eq(3)
        end

        it "updates multiple counters atomically" do
          ThreadCounter.insert_or_increment(
            hostname: hostname,
            process_id: process_id,
            thread_id: thread_id,
            publishing_count: 1,
            published_count: 2,
            failed_count: 3
          )

          row = ThreadCounter.find_by(
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
            ThreadCounter.insert_or_increment(
              hostname: hostname,
              process_id: process_id,
              thread_id: thread_id,
              queued_count: 1
            )
          end

          count = ThreadCounter.where(
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
