require 'spec_helper'

module Outboxer
  RSpec.describe Messages do
    let(:fixed_time) { Time.now.utc }

    before do
      allow(Time).to receive(:now).and_return(fixed_time)
    end

    describe '.stats' do
      context 'when no messages exist' do
        it 'returns { count: 0, oldest_updated_at: nil } for all statuses' do
          expect(Messages.stats).to eq({
            all: { count: 0, oldest_updated_at: nil },
            queued: { count: 0, oldest_updated_at: nil },
            dequeued: { count: 0, oldest_updated_at: nil },
            publishing: { count: 0, oldest_updated_at: nil },
            failed: { count: 0, oldest_updated_at: nil }
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

        it 'returns correct stats for each status' do
          expect(Messages.stats).to eq({
            all: { count: 14, oldest_updated_at: fixed_time - 4.hours },
            queued: { count: 2, oldest_updated_at: fixed_time - 1.hour },
            dequeued: { count: 3, oldest_updated_at: fixed_time - 2.hours },
            publishing: { count: 5, oldest_updated_at: fixed_time - 3.hours },
            failed: { count: 4, oldest_updated_at: fixed_time - 4.hours }
          })
        end
      end
    end
  end
end
