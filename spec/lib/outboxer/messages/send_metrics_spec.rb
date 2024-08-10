require 'spec_helper'

module Outboxer
  RSpec.describe Messages do
    describe '.send_metrics' do
      let(:metrics) do
        {
          queued: { count: 10, latency: 300 },
          dequeued: { count: 5, latency: 150 },
          publishing: { count: 3, latency: 110 },
          published: { count: 2, latency: 100 },
          failed: { count: 12, latency: 120 },
        }
      end
      let(:tags) { ['env:production'] }
      let(:statsd) { instance_double('Statsd') }
      let(:logger) { instance_double('Logger') }

      before do
        allow(statsd).to receive(:batch).and_yield
        allow(statsd).to receive(:gauge)
      end

      it 'sends metrics to statsd with correct tags' do
        Messages.send_metrics(metrics: metrics, tags: tags, statsd: statsd, logger: logger)

        metrics.each do |status, metric|
          expect(statsd).to have_received(:gauge).with(
            "outboxer.messages.count", metric[:count], tags: tags + ["status:#{status}"])

          expect(statsd).to have_received(:gauge).with(
            "outboxer.messages.latency", metric[:latency], tags: tags + ["status:#{status}"])
        end
      end

      it 'sends metrics inside a batch' do
        expect(statsd).to receive(:batch).and_yield

        Messages.send_metrics(metrics: metrics, tags: tags, statsd: statsd, logger: logger)
      end
    end
  end
end
