require "rails_helper"

module Outboxer
  module Models
    class Message
      RSpec.describe Count, type: :model do
        describe ".insert_or_increment_by" do
          let(:hostname)   { "test-host" }
          let(:process_id) { 12_345 }
          let(:thread_id)  { 999 }

          it "inserts a new row successfully" do
            expect do
              Count.insert_or_increment_by(
                hostname: hostname,
                process_id: process_id,
                thread_id: thread_id,
                queued: 1
              )
            end.to change(Count, :count).by(1)

            row = Count.find_by(
              hostname: hostname,
              process_id: process_id,
              thread_id: thread_id
            )

            expect(row).not_to be_nil
            expect(row.queued).to eq(1)
          end

          it "increments existing counts if called again" do
            Count.insert_or_increment_by(
              hostname: hostname,
              process_id: process_id,
              thread_id: thread_id,
              queued: 1
            )

            Count.insert_or_increment_by(
              hostname: hostname,
              process_id: process_id,
              thread_id: thread_id,
              queued: 2
            )

            row = Count.find_by(
              hostname: hostname,
              process_id: process_id,
              thread_id: thread_id
            )

            expect(row.queued).to eq(3)
          end

          it "updates multiple counts atomically" do
            Count.insert_or_increment_by(
              hostname: hostname,
              process_id: process_id,
              thread_id: thread_id,
              publishing: 1,
              published: 2,
              failed: 3
            )

            row = Count.find_by(
              hostname: hostname,
              process_id: process_id,
              thread_id: thread_id
            )

            expect(row.publishing).to eq(1)
            expect(row.published).to eq(2)
            expect(row.failed).to eq(3)
          end

          it "does not create duplicate rows on repeated calls" do
            3.times do
              Count.insert_or_increment_by(
                hostname: hostname,
                process_id: process_id,
                thread_id: thread_id,
                queued: 1
              )
            end

            count = Count.where(
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
