# frozen_string_literal: true

require "rails_helper"

module Outboxer
  RSpec.describe Counter do
    let(:time_now) { Time.utc(2025, 1, 1, 0, 0, 0) }
    let(:publisher_a) { 100 }
    let(:publisher_b) { 200 }

    before { Models::Counter.delete_all }

    describe ".rollup" do
      context "when historic counter does not exist" do
        let!(:thread_1) do
          Models::Counter.create!(
            hostname: "worker1.test.local", process_id: 111, thread_id: 21_001,
            publisher_id: publisher_a,
            queued_count: 1, publishing_count: 2,
            published_count: 3, failed_count: 4,
            created_at: time_now, updated_at: time_now)
        end

        let!(:thread_2) do
          Models::Counter.create!(
            hostname: "worker1.test.local", process_id: 111, thread_id: 21_002,
            publisher_id: publisher_a,
            queued_count: 10, publishing_count: 20,
            published_count: 30, failed_count: 40,
            created_at: time_now, updated_at: time_now)
        end

        it "creates the historic counter and rolls up all the thread counters" do
          result = Counter.rollup(publisher_id: publisher_a, time: time_now)

          expect(result).to eq(
            queued_count: 11,
            publishing_count: 22,
            published_count: 33,
            failed_count: 44
          )

          historic = Models::Counter.find_by!(
            hostname: Counter::HISTORIC_HOSTNAME,
            process_id: Counter::HISTORIC_PROCESS_ID,
            thread_id: Counter::HISTORIC_THREAD_ID)

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
            created_at: time_now, updated_at: time_now)
        end

        let!(:thread) do
          Models::Counter.create!(
            hostname: "worker2.test.local", process_id: 222, thread_id: 22_001,
            publisher_id: publisher_a,
            queued_count: 1, publishing_count: 1,
            published_count: 1, failed_count: 1,
            created_at: time_now, updated_at: time_now)
        end

        it "increments existing historic counters" do
          result = Counter.rollup(publisher_id: publisher_a, time: time_now)

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

      context "when thread counters belong to a different publisher" do
        let!(:thread) do
          Models::Counter.create!(
            hostname: "worker3.test.local", process_id: 333, thread_id: 23_001,
            publisher_id: publisher_b,
            queued_count: 5, publishing_count: 6,
            published_count: 7, failed_count: 8,
            created_at: time_now, updated_at: time_now)
        end

        it "creates the historic counter but does not include other publishers" do
          result = Counter.rollup(publisher_id: publisher_a, time: time_now)

          expect(result).to eq(
            queued_count: 0,
            publishing_count: 0,
            published_count: 0,
            failed_count: 0
          )

          historic = Models::Counter.find_by!(
            hostname: Counter::HISTORIC_HOSTNAME,
            process_id: Counter::HISTORIC_PROCESS_ID,
            thread_id: Counter::HISTORIC_THREAD_ID)

          expect(historic.queued_count).to eq(0)
          expect(historic.publishing_count).to eq(0)
          expect(historic.published_count).to eq(0)
          expect(historic.failed_count).to eq(0)

          expect(Models::Counter.where(publisher_id: publisher_b).count).to eq(1)
        end
      end

      context "when thread counters have nil publisher_id" do
        let!(:thread) do
          Models::Counter.create!(
            hostname: "worker4.test.local", process_id: 444, thread_id: 24_001,
            publisher_id: nil,
            queued_count: 2, publishing_count: 3,
            published_count: 4, failed_count: 5,
            created_at: time_now, updated_at: time_now)
        end

        it "includes nil publisher rows in the rollup" do
          result = Counter.rollup(publisher_id: publisher_a, time: time_now)

          expect(result).to eq(
            queued_count: 2,
            publishing_count: 3,
            published_count: 4,
            failed_count: 5
          )

          historic = Models::Counter.find_by!(
            hostname: Counter::HISTORIC_HOSTNAME,
            process_id: Counter::HISTORIC_PROCESS_ID,
            thread_id: Counter::HISTORIC_THREAD_ID)

          expect(historic.queued_count).to eq(2)
          expect(historic.publishing_count).to eq(3)
          expect(historic.published_count).to eq(4)
          expect(historic.failed_count).to eq(5)
        end
      end

      context "when no matching counters exist" do
        it "creates a historic counter with all zero counts" do
          result = Counter.rollup(publisher_id: publisher_a, time: time_now)

          expect(result).to eq(
            queued_count: 0,
            publishing_count: 0,
            published_count: 0,
            failed_count: 0
          )

          historic = Models::Counter.find_by!(
            hostname: Counter::HISTORIC_HOSTNAME,
            process_id: Counter::HISTORIC_PROCESS_ID,
            thread_id: Counter::HISTORIC_THREAD_ID)

          expect(historic.queued_count).to eq(0)
          expect(historic.publishing_count).to eq(0)
          expect(historic.published_count).to eq(0)
          expect(historic.failed_count).to eq(0)
        end
      end
    end

    describe ".total" do
      before do
        Models::Counter.create!(
          hostname: Counter::HISTORIC_HOSTNAME,
          process_id: Counter::HISTORIC_PROCESS_ID,
          thread_id: Counter::HISTORIC_THREAD_ID,
          queued_count: 10, publishing_count: 20,
          published_count: 30, failed_count: 40,
          created_at: time_now, updated_at: time_now)

        Models::Counter.create!(
          hostname: "worker5.test.local", process_id: 555, thread_id: 25_001,
          publisher_id: publisher_a,
          queued_count: 5, publishing_count: 6,
          published_count: 7, failed_count: 8,
          created_at: time_now, updated_at: time_now)
      end

      it "returns total counts across all counters" do
        totals = Counter.total

        expect(totals).to eq(
          queued_count: 15,
          publishing_count: 26,
          published_count: 37,
          failed_count: 48
        )
      end
    end
  end
end
