require "rails_helper"

module Outboxer
  RSpec.describe Message do
    describe ".metrics" do
      let(:current_utc_time) { ::Time.now.utc }
      let(:time) { double("Time", now: double("Time", utc: current_utc_time)) }

      context "when there are messages in different statuses" do
        let!(:historic_counter) do
          create(:outboxer_counter, :historic, failed_count: 500, published_count: 500)
        end

        let!(:oldest_queued_message) do
          Message.queue(messageable: OpenStruct.new(id: "1", type: "Blah"))
        end

        let!(:newest_queued_message) do
          Message.queue(messageable: OpenStruct.new(id: "2", type: "Blah"))
        end

        let!(:oldest_publishing_message) do
          message = Message.queue(messageable: OpenStruct.new(id: "3", type: "Blah"))
          Message.publishing
          message
        end

        let!(:newest_publishing_message) do
          message = Message.queue(messageable: OpenStruct.new(id: "4", type: "Blah"))
          Message.publishing
          message
        end

        let!(:oldest_published_message) do
          message = Message.queue(messageable: OpenStruct.new(id: "5", type: "Blah"))
          Message.publish do |_message|
            # do nothing
          end
          message
        end

        let!(:newest_published_message) do
          message = Message.queue(messageable: OpenStruct.new(id: "6", type: "Blah"))
          Message.publish do |_message|
            # do nothing
          end
          message
        end

        let!(:oldest_failed_message) do
          message = Message.queue(messageable: OpenStruct.new(id: "7", type: "Blah"))
          Message.publish do |_message|
            raise "error"
          end
          message
        end

        let!(:newest_failed_message) do
          message = Message.queue(messageable: OpenStruct.new(id: "8", type: "Blah"))
          Message.publish do |_message|
            raise "error"
          end
          message
        end

        it "returns correct settings" do
          metrics = Message.metrics

          expect(metrics).to eq(
            all: {
              count: { total: 1008 }
            },
            queued: {
              count: { total: 2 },
              latency: 0,
              throughput: 0
            },
            publishing: {
              count: { total: 2 },
              latency: 0,
              throughput: 0
            },
            published: {
              count: { total: 502 },
              latency: 0,
              throughput: 0
            },
            failed: {
              count: { total: 502 },
              latency: 0,
              throughput: 0
            })
        end
      end

      context "when there are no messages in a specific status" do
        it "returns zero count and latency for that status" do
          metrics = Message.metrics

          expect(metrics).to eq(
            all: { count: { total: 0 } },
            queued: { count: { total: 0 }, latency: 0, throughput: 0 },
            publishing: { count: { total: 0 }, latency: 0, throughput: 0 },
            published: { count: { total: 0 }, latency: 0, throughput: 0 },
            failed: { count: { total: 0 }, latency: 0, throughput: 0 })
        end
      end

      context "when no messages exist" do
        it "returns zero count and latency for all statuses" do
          metrics = Message.metrics

          expect(metrics).to eq(
            all: { count: { total: 0 } },
            queued: { count: { total: 0 }, latency: 0, throughput: 0 },
            publishing: { count: { total: 0 }, latency: 0, throughput: 0 },
            published: { count: { total: 0 }, latency: 0, throughput: 0 },
            failed: { count: { total: 0 }, latency: 0, throughput: 0 })
        end
      end
    end
  end
end
