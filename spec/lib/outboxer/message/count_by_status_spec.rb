# frozen_string_literal: true

require "rails_helper"

module Outboxer
  RSpec.describe Message do
    describe ".count_by_status" do
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

      it "returns total counts by status" do
        expect(Message.count_by_status).to eq(
          queued: 15, publishing: 26, published: 37, failed: 48, total: 126)
      end
    end
  end
end
