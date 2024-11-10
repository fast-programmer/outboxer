require 'spec_helper'

module Outboxer
  RSpec.describe Publisher do
    describe '.find_by_id' do
      context 'when the publisher exists' do
        let!(:publisher) do
          create(:outboxer_publisher,
            name: 'server-09:67000',
            status: Models::Publisher::Status::PUBLISHING,
            settings: {
              'buffer' => 1000,
              'concurrency' => 2,
              'tick' => 0.1,
              'poll' => 5.0,
              'heartbeat' => 5.0 },
            metrics: {
              'throughput' => 700,
              'latency' => 0,
              'cpu' => '10.5%',
              'rss' => '40.95 MB',
              'rtt' => '3.35 ms' },
            created_at: DateTime.parse("2024-11-10T02:00:00"),
            updated_at: DateTime.parse("2024-11-10T02:00:10")
          )
        end
        let!(:signals) do
          [
            create(:outboxer_signal,
              name: 'TSTP',
              created_at: DateTime.parse("2024-11-10T02:00:11"),
              publisher_id: publisher.id),
            create(:outboxer_signal,
              name: 'TERM',
              created_at: DateTime.parse("2024-11-10T02:00:12"),
              publisher_id: publisher.id)
          ]
        end

        it 'returns the publisher and signals' do
          result = Publisher.find_by_id(id: publisher.id)

          expect(result[:id]).to eq(publisher.id)
          expect(result[:name]).to eq(publisher.name)
          expect(result[:status]).to eq('publishing')
          expect(result[:settings]).to eq({
            'buffer' => 1000,
            'concurrency' => 2,
            'tick' => 0.1,
            'poll' => 5.0,
            'heartbeat' => 5
          })
          expect(result[:created_at]).to eq(publisher.created_at.utc)
          expect(result[:metrics]).to eq({
            'throughput' => 700,
            'latency' => 0,
            'cpu' => '10.5%',
            'rss' => '40.95 MB',
            'rtt' => '3.35 ms'
          })
          expect(result[:created_at]).to eq(publisher.created_at.utc)
          expect(result[:updated_at]).to eq(publisher.updated_at.utc)

          expect(result[:signals][0][:id]).to eq(signals[0].id)
          expect(result[:signals][0][:name]).to eq(signals[0].name)
          expect(result[:signals][0][:created_at]).to eq(signals[0].created_at)

          expect(result[:signals][1][:id]).to eq(signals[1].id)
          expect(result[:signals][1][:name]).to eq(signals[1].name)
          expect(result[:signals][1][:created_at]).to eq(signals[1].created_at)
        end
      end

      context 'when the publisher does not exist' do
        it 'raises a NotFound error' do
          expect { Publisher.find_by_id(id: -1) }.to raise_error(Publisher::NotFound)
        end
      end
    end
  end
end
