require "rails_helper"

module Outboxer
  module Models
    RSpec.describe ThreadCounter, type: :model do
      describe ".insert_or_increment" do
        let(:hostname)   { "test-host" }
        let(:process_id) { 12_345 }
        let(:thread_id)  { 999 }
        let(:now)        { Time.now.utc }

        it "inserts a new row and returns its id" do
          thread_counter = ThreadCounter.insert_or_increment(
            hostname: hostname,
            process_id: process_id,
            thread_id: thread_id,
            queued_count: 1,
            time: now
          )

          expect(thread_counter).to be_a(Hash)
          expect(thread_counter).to include(:id)
          expect(thread_counter[:id]).to be_present

          row = ThreadCounter.find(thread_counter[:id])
          expect(row.hostname).to eq(hostname)
          expect(row.queued_count).to eq(1)
        end

        it "increments existing counts if called again" do
          first = ThreadCounter.insert_or_increment(
            hostname: hostname,
            process_id: process_id,
            thread_id: thread_id,
            queued_count: 1
          )

          second = ThreadCounter.insert_or_increment(
            hostname: hostname,
            process_id: process_id,
            thread_id: thread_id,
            queued_count: 2
          )

          expect(second[:id]).to eq(first[:id])

          row = ThreadCounter.find(second[:id])
          expect(row.queued_count).to eq(3)
        end

        it "updates multiple counters atomically" do
          thread_counter = ThreadCounter.insert_or_increment(
            hostname: hostname,
            process_id: process_id,
            thread_id: thread_id,
            publishing_count: 1,
            published_count: 2,
            failed_count: 3
          )

          row = ThreadCounter.find(thread_counter[:id])
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
