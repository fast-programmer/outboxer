require "rails_helper"

module Outboxer
  RSpec.describe Message do
    describe ".rollup_counts" do
      let(:current_utc_time) { Time.utc(2025, 1, 1, 0, 0, 0) }

      before { Models::Thread.delete_all }

      context "when historic count does not exist" do
        let!(:thread_1) do
          Models::Thread.create!(
            hostname: "worker1.test.local", process_id: 111, thread_id: 21_001,
            queued_message_count: 1, publishing_message_count: 2,
            published_message_count: 3, failed_message_count: 4,
            created_at: current_utc_time, updated_at: current_utc_time
          )
        end

        let!(:thread_2) do
          Models::Thread.create!(
            hostname: "worker1.test.local", process_id: 111, thread_id: 21_002,
            queued_message_count: 10, publishing_message_count: 20,
            published_message_count: 30, failed_message_count: 40,
            created_at: current_utc_time, updated_at: current_utc_time
          )
        end

        it "creates the historic message count and rolls up all thread message counts" do
          result = Message.rollup_counts(time: Time)

          expect(result).to eq(
            queued_message_count: 11,
            publishing_message_count: 22,
            published_message_count: 33,
            failed_message_count: 44
          )

          historic_thread = Models::Thread.find_by!(
            hostname: Models::Thread::HISTORIC_HOSTNAME,
            process_id: Models::Thread::HISTORIC_PROCESS_ID,
            thread_id: Models::Thread::HISTORIC_THREAD_ID
          )

          expect(historic_thread.queued_message_count).to eq(11)
          expect(historic_thread.publishing_message_count).to eq(22)
          expect(historic_thread.published_message_count).to eq(33)
          expect(historic_thread.failed_message_count).to eq(44)

          expect(
            Models::Thread.where.not(
              hostname: Models::Thread::HISTORIC_HOSTNAME)
          ).to be_empty
        end
      end

      context "when historic count already exists" do
        let!(:historic_count) do
          Models::Thread.create!(
            hostname: Models::Thread::HISTORIC_HOSTNAME,
            process_id: Models::Thread::HISTORIC_PROCESS_ID,
            thread_id: Models::Thread::HISTORIC_THREAD_ID,
            queued_message_count: 100, publishing_message_count: 200,
            published_message_count: 300, failed_message_count: 400,
            created_at: current_utc_time, updated_at: current_utc_time
          )
        end

        let!(:thread_count) do
          Models::Thread.create!(
            hostname: "worker2.test.local", process_id: 222, thread_id: 22_001,
            queued_message_count: 1, publishing_message_count: 1,
            published_message_count: 1, failed_message_count: 1,
            created_at: current_utc_time, updated_at: current_utc_time
          )
        end

        it "increments existing historic count" do
          result = Message.rollup_counts(time: Time)

          expect(result).to eq(
            queued_message_count: 101, publishing_message_count: 201,
            published_message_count: 301, failed_message_count: 401)

          historic_count.reload

          expect(historic_count.queued_message_count).to eq(101)
          expect(historic_count.publishing_message_count).to eq(201)
          expect(historic_count.published_message_count).to eq(301)
          expect(historic_count.failed_message_count).to eq(401)
        end
      end

      context "when no message count exists" do
        it "creates a historic message count with zero counts" do
          result = Message.rollup_counts(time: Time)

          expect(result).to eq(
            queued_message_count: 0, publishing_message_count: 0,
            published_message_count: 0, failed_message_count: 0
          )

          historic_thread = Models::Thread.find_by!(
            hostname: Models::Thread::HISTORIC_HOSTNAME,
            process_id: Models::Thread::HISTORIC_PROCESS_ID,
            thread_id: Models::Thread::HISTORIC_THREAD_ID
          )

          expect(historic_thread.queued_message_count).to eq(0)
          expect(historic_thread.publishing_message_count).to eq(0)
          expect(historic_thread.published_message_count).to eq(0)
          expect(historic_thread.failed_message_count).to eq(0)
        end
      end
    end
  end
end
