require 'spec_helper'

module Outboxer
  RSpec.describe Messages do
    describe '.metrics' do
      let(:current_utc_time) { Time.now.utc }

      context 'when there are messages in different statuses' do
        before do
          Models::Metric
            .find_by!(name: 'messages.published.count.historic')
            .update!(value: BigDecimal('500'))
        end

        let!(:oldest_queued_message) do
          create(:outboxer_message, :queued, updated_at: 15.minutes.ago)
        end

        let!(:newest_queued_message) do
          create(:outboxer_message, :queued, updated_at: 5.minutes.ago)
        end

        let!(:oldest_dequeued_message) do
          create(:outboxer_message, :dequeued, updated_at: 20.minutes.ago)
        end

        let!(:newest_dequeued_message) do
          create(:outboxer_message, :dequeued, updated_at: 4.minutes.ago)
        end

        let!(:oldest_publishing_message) do
          create(:outboxer_message, :publishing, updated_at: 25.minutes.ago)
        end

        let!(:newest_publishing_message) do
          create(:outboxer_message, :publishing, updated_at: 3.minutes.ago)
        end

        let!(:oldest_published_message) do
          create(:outboxer_message, :published, updated_at: 30.minutes.ago)
        end

        let!(:newest_published_message) do
          create(:outboxer_message, :published, updated_at: 4.minutes.ago)
        end

        let!(:oldest_failed_message) do
          create(:outboxer_message, :failed, updated_at: 35.minutes.ago)
        end

        let!(:newest_failed_message) do
          create(:outboxer_message, :failed, updated_at: 10.minutes.ago)
        end

        it 'returns correct metrics' do
          metrics = Messages.metrics(current_utc_time: current_utc_time)

          expect(metrics).to eq(
            queued: {
              count: { current: 2 },
              latency: (current_utc_time - oldest_queued_message.updated_at.utc).to_i,
              throughput: 0,
            },
            dequeued: {
              count: { current: 2 },
              latency: (current_utc_time - oldest_dequeued_message.updated_at.utc).to_i,
              throughput: 0,
            },
            publishing: {
              count: { current: 2 },
              latency: (current_utc_time - oldest_publishing_message.updated_at.utc).to_i,
              throughput: 0,
            },
            published: {
              count: { current: 2, historic: 500 },
              latency: (current_utc_time - oldest_published_message.updated_at.utc).to_i,
              throughput: 0,
            },
            failed: {
              count: { current: 2 },
              latency: (current_utc_time - oldest_failed_message.updated_at.utc).to_i,
              throughput: 0,
            }
          )
        end
      end

      context 'when there are no messages in a specific status' do
        it 'returns zero count and latency for that status' do
          metrics = Messages.metrics(current_utc_time: current_utc_time)

          expect(metrics).to eq(
            queued: { count: { current: 0 }, latency: 0, throughput: 0 },
            dequeued: { count: { current: 0 }, latency: 0, throughput: 0 },
            publishing: { count: { current: 0 }, latency: 0, throughput: 0 },
            published: { count: { current: 0, historic: 0 }, latency: 0, throughput: 0 },
            failed: { count: { current: 0 }, latency: 0, throughput: 0 }
          )
        end
      end

      context 'when no messages exist' do
        it 'returns zero count and latency for all statuses' do
          metrics = Messages.metrics(current_utc_time: current_utc_time)

          expect(metrics).to eq(
            queued: { count: { current: 0 }, latency: 0, throughput: 0 },
            dequeued: { count: { current: 0 }, latency: 0, throughput: 0 },
            publishing: { count: { current: 0 }, latency: 0, throughput: 0 },
            published: { count: { current: 0, historic: 0 }, latency: 0, throughput: 0 },
            failed: { count: { current: 0 }, latency: 0, throughput: 0 }
          )
        end
      end
    end
  end
end
