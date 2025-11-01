# frozen_string_literal: true

require "rails_helper"

module Outboxer
  RSpec.describe Message do
    describe ".metrics_by_status" do
      let(:current_utc_time) { Time.utc(2025, 1, 1, 0, 0, 0) }

      before { Models::Message::Count.delete_all }

      before do
        Models::Message::Count.create!(
          hostname: Models::Message::Count::HISTORIC_HOSTNAME,
          process_id: Models::Message::Count::HISTORIC_PROCESS_ID,
          thread_id: Models::Message::Count::HISTORIC_THREAD_ID,
          queued: 10, publishing: 20, published: 30, failed: 40,
          created_at: current_utc_time, updated_at: current_utc_time
        )

        Models::Message::Count.create!(
          hostname: "worker5.test.local", process_id: 555, thread_id: 25_001,
          queued: 5, publishing: 6, published: 7, failed: 8,
          created_at: current_utc_time, updated_at: current_utc_time
        )
      end

      it "returns metrics by status" do
        expect(Message.metrics_by_status).to eq({
          queued: { count: 15, latency: 0 },
          publishing: { count: 26, latency: 0 },
          published: { count: 37, latency: 0 },
          failed: { count: 48, latency: 0 },
          total: { count: 126, latency: 0 }
        })
      end
    end
  end
end
