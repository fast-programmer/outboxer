# frozen_string_literal: true

require "rails_helper"

module Outboxer
  RSpec.describe Message do
    describe ".rollup_counts" do
      let(:current_utc_time) { Time.utc(2025, 1, 1, 0, 0, 0) }

      before { Models::Message::Count.delete_all }

      context "when historic count does not exist" do
        let!(:thread_1) do
          Models::Message::Count.create!(
            hostname: "worker1.test.local", process_id: 111, thread_id: 21_001,
            queued: 1, publishing: 2,
            published: 3, failed: 4,
            created_at: current_utc_time, updated_at: current_utc_time
          )
        end

        let!(:thread_2) do
          Models::Message::Count.create!(
            hostname: "worker1.test.local", process_id: 111, thread_id: 21_002,
            queued: 10, publishing: 20,
            published: 30, failed: 40,
            created_at: current_utc_time, updated_at: current_utc_time
          )
        end

        it "creates the historic counter and rolls up all thread counters" do
          result = Message.rollup_counts(time: Time)

          expect(result).to eq(
            queued: 11,
            publishing: 22,
            published: 33,
            failed: 44
          )

          historic_count = Models::Message::Count.find_by!(
            hostname: Models::Message::Count::HISTORIC_HOSTNAME,
            process_id: Models::Message::Count::HISTORIC_PROCESS_ID,
            thread_id: Models::Message::Count::HISTORIC_THREAD_ID
          )

          expect(historic_count.queued).to eq(11)
          expect(historic_count.publishing).to eq(22)
          expect(historic_count.published).to eq(33)
          expect(historic_count.failed).to eq(44)

          expect(
            Models::Message::Count.where.not(hostname: Models::Message::Count::HISTORIC_HOSTNAME)
          ).to be_empty
        end
      end

      context "when historic count already exists" do
        let!(:historic_count) do
          Models::Message::Count.create!(
            hostname: Models::Message::Count::HISTORIC_HOSTNAME,
            process_id: Models::Message::Count::HISTORIC_PROCESS_ID,
            thread_id: Models::Message::Count::HISTORIC_THREAD_ID,
            queued: 100, publishing: 200, published: 300, failed: 400,
            created_at: current_utc_time, updated_at: current_utc_time
          )
        end

        let!(:thread_count) do
          Models::Message::Count.create!(
            hostname: "worker2.test.local", process_id: 222, thread_id: 22_001,
            queued: 1, publishing: 1, published: 1, failed: 1,
            created_at: current_utc_time, updated_at: current_utc_time
          )
        end

        it "increments existing historic count" do
          result = Message.rollup_counts(time: Time)

          expect(result).to eq(
            queued: 101, publishing: 201, published: 301, failed: 401)

          historic_count.reload

          expect(historic_count.queued).to eq(101)
          expect(historic_count.publishing).to eq(201)
          expect(historic_count.published).to eq(301)
          expect(historic_count.failed).to eq(401)
        end
      end

      context "when no counters exist" do
        it "creates a historic counter with zero counts" do
          result = Message.rollup_counts(time: Time)

          expect(result).to eq(queued: 0, publishing: 0, published: 0, failed: 0)

          historic_count = Models::Message::Count.find_by!(
            hostname: Models::Message::Count::HISTORIC_HOSTNAME,
            process_id: Models::Message::Count::HISTORIC_PROCESS_ID,
            thread_id: Models::Message::Count::HISTORIC_THREAD_ID
          )

          expect(historic_count.queued).to eq(0)
          expect(historic_count.publishing).to eq(0)
          expect(historic_count.published).to eq(0)
          expect(historic_count.failed).to eq(0)
        end
      end
    end
  end
end
