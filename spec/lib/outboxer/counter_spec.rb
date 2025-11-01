# frozen_string_literal: true

require "rails_helper"

module Outboxer
  RSpec.describe Message do
    describe ".rollup" do
      let(:current_utc_time) { Time.utc(2025, 1, 1, 0, 0, 0) }

      before { Models::Message::Count.delete_all }

      context "when historic counter does not exist" do
        let!(:thread_1) do
          Models::Counter.create!(
            hostname: "worker1.test.local", process_id: 111, thread_id: 21_001,
            queued_count: 1, publishing_count: 2,
            published_count: 3, failed_count: 4,
            created_at: current_utc_time, updated_at: current_utc_time
          )
        end

        let!(:thread_2) do
          Models::Message::Count.create!(
            hostname: "worker1.test.local", process_id: 111, thread_id: 21_002,
            queued_count: 10, publishing_count: 20,
            published_count: 30, failed_count: 40,
            created_at: current_utc_time, updated_at: current_utc_time
          )
        end

        it "creates the historic counter and rolls up all thread counters" do
          result = Message.rollup_counts(time: Time)

          expect(result).to eq(
            queued_count: 11,
            publishing_count: 22,
            published_count: 33,
            failed_count: 44
          )

          historic = Models::Message::Count.find_by!(
            hostname: Models::Message::Count::HISTORIC_HOSTNAME,
            process_id: Models::Message::Count::HISTORIC_PROCESS_ID,
            thread_id: Models::Message::Count::HISTORIC_THREAD_ID
          )

          expect(historic.queued_count).to eq(11)
          expect(historic.publishing_count).to eq(22)
          expect(historic.published_count).to eq(33)
          expect(historic.failed_count).to eq(44)

          expect(Models::Counter.where.not(hostname: Counter::HISTORIC_HOSTNAME)).to be_empty
        end
      end

      context "when historic counter already exists" do
        let!(:historic) do
          Models::Counter.create!(
            hostname: Counter::HISTORIC_HOSTNAME,
            process_id: Counter::HISTORIC_PROCESS_ID,
            thread_id: Counter::HISTORIC_THREAD_ID,
            queued_count: 100, publishing_count: 200,
            published_count: 300, failed_count: 400,
            created_at: current_utc_time, updated_at: current_utc_time
          )
        end

        let!(:thread) do
          Models::Counter.create!(
            hostname: "worker2.test.local", process_id: 222, thread_id: 22_001,
            queued_count: 1, publishing_count: 1,
            published_count: 1, failed_count: 1,
            created_at: current_utc_time, updated_at: current_utc_time
          )
        end

        it "increments existing historic counters" do
          result = Counter.rollup(time: Time)

          expect(result).to eq(
            queued_count: 101,
            publishing_count: 201,
            published_count: 301,
            failed_count: 401
          )

          historic.reload

          expect(historic.queued_count).to eq(101)
          expect(historic.publishing_count).to eq(201)
          expect(historic.published_count).to eq(301)
          expect(historic.failed_count).to eq(401)
        end
      end

      context "when no counters exist" do
        it "creates a historic counter with zero counts" do
          result = Counter.rollup(time: Time)

          expect(result).to eq(
            queued_count: 0,
            publishing_count: 0,
            published_count: 0,
            failed_count: 0
          )

          historic = Models::Counter.find_by!(
            hostname: Counter::HISTORIC_HOSTNAME,
            process_id: Counter::HISTORIC_PROCESS_ID,
            thread_id: Counter::HISTORIC_THREAD_ID
          )

          expect(historic.queued_count).to eq(0)
          expect(historic.publishing_count).to eq(0)
          expect(historic.published_count).to eq(0)
          expect(historic.failed_count).to eq(0)
        end
      end
    end
  end
end
