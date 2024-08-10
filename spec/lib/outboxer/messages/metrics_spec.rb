require 'spec_helper'

module Outboxer
  RSpec.describe Messages do
    describe '.metrics' do
      let(:current_utc_time) { Time.now.utc }

      context 'when there are messages in different statuses' do
        let!(:queued_message_old) do
          create(:outboxer_message, :queued, updated_at: 15.minutes.ago)
        end

        let!(:queued_message_new) do
          create(:outboxer_message, :queued, updated_at: 5.minutes.ago)
        end

        let!(:dequeued_message_old) do
          create(:outboxer_message, :dequeued, updated_at: 20.minutes.ago)
        end

        let!(:dequeued_message_new) do
          create(:outboxer_message, :dequeued, updated_at: 4.minutes.ago)
        end

        let!(:publishing_message_old) do
          create(:outboxer_message, :publishing, updated_at: 25.minutes.ago)
        end

        let!(:publishing_message_new) do
          create(:outboxer_message, :publishing, updated_at: 3.minutes.ago)
        end

        let!(:published_message_old) do
          create(:outboxer_message, :published, updated_at: 30.minutes.ago)
        end

        let!(:published_message_new) do
          create(:outboxer_message, :published, updated_at: 4.minutes.ago)
        end

        let!(:failed_message_old) do
          create(:outboxer_message, :failed, updated_at: 35.minutes.ago)
        end

        let!(:failed_message_new) do
          create(:outboxer_message, :failed, updated_at: 10.minutes.ago)
        end

        it 'returns correct metrics' do
          metrics = Messages.metrics(current_utc_time: current_utc_time)

          expect(metrics).to eq(
            queued: {
              count: 2,
              latency: (current_utc_time - queued_message_old.updated_at.utc).to_i
            },
            dequeued: {
              count: 2,
              latency: (current_utc_time - dequeued_message_old.updated_at.utc).to_i
            },
            publishing: {
              count: 2,
              latency: (current_utc_time - publishing_message_old.updated_at.utc).to_i
            },
            published: {
              count: 2,
              latency: (current_utc_time - published_message_old.updated_at.utc).to_i
            },
            failed: {
              count: 2,
              latency: (current_utc_time - failed_message_old.updated_at.utc).to_i
            }
          )
        end
      end

      context 'when there are no messages in a specific status' do
        it 'returns zero count and latency for that status' do
          metrics = Messages.metrics(current_utc_time: current_utc_time)

          expect(metrics).to eq(
            queued: { count: 0, latency: 0 },
            dequeued: { count: 0, latency: 0 },
            publishing: { count: 0, latency: 0 },
            published: { count: 0, latency: 0 },
            failed: { count: 0, latency: 0 }
          )
        end
      end

      context 'when no messages exist' do
        it 'returns zero count and latency for all statuses' do
          metrics = Messages.metrics(current_utc_time: current_utc_time)

          expect(metrics).to eq(
            queued: { count: 0, latency: 0 },
            dequeued: { count: 0, latency: 0 },
            publishing: { count: 0, latency: 0 },
            published: { count: 0, latency: 0 },
            failed: { count: 0, latency: 0 }
          )
        end
      end
    end
  end
end
