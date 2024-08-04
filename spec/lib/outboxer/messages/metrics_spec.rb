require 'spec_helper'

module Outboxer
  RSpec.describe Messages do
    let(:fixed_time) { Time.now.utc }

    before do
      allow(Time).to receive(:now).and_return(fixed_time)
    end

    describe '.metrics' do
      context 'when no messages exist' do
        it 'returns metrics with count, oldest_updated_at and latency for all statuses' do
          expect(Messages.metrics(current_utc_time: fixed_time)).to eq({
            all: { count: 0, oldest_updated_at: nil, latency: nil },
            queued: { count: 0, oldest_updated_at: nil, latency: nil },
            dequeued: { count: 0, oldest_updated_at: nil, latency: nil },
            publishing: { count: 0, oldest_updated_at: nil, latency: nil },
            failed: { count: 0, oldest_updated_at: nil, latency: nil }
          })
        end
      end

      context 'when messages exist' do
        before do
          create_list(:outboxer_message, 2, :queued, updated_at: fixed_time - 1.hour)
          create_list(:outboxer_message, 3, :dequeued, updated_at: fixed_time - 2.hours)
          create_list(:outboxer_message, 5, :publishing, updated_at: fixed_time - 3.hours)
          create_list(:outboxer_message, 4, :failed, updated_at: fixed_time - 4.hours)
        end

        it 'returns correct metrics including latency for each status' do
          expect(Messages.metrics(current_utc_time: fixed_time)).to eq({
            all: { count: 14, oldest_updated_at: fixed_time - 4.hours, latency: 14400 },
            queued: { count: 2, oldest_updated_at: fixed_time - 1.hour, latency: 3600 },
            dequeued: { count: 3, oldest_updated_at: fixed_time - 2.hours, latency: 7200 },
            publishing: { count: 5, oldest_updated_at: fixed_time - 3.hours, latency: 10800 },
            failed: { count: 4, oldest_updated_at: fixed_time - 4.hours, latency: 14400 }
          })
        end
      end
    end
  end
end
