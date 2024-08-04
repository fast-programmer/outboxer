require 'spec_helper'
require 'statsd-ruby'

module Outboxer
  RSpec.describe Messages do
    let(:statsd) { instance_double(::Statsd) }
    let(:current_time_utc) { Time.now.utc }
    let(:tags) { ['env:test'] }

    before do
      allow(statsd).to receive(:gauge)
      allow(statsd).to receive(:batch).and_yield(statsd)
    end

    before do
      create_list(:outboxer_message, 2, :queued, updated_at: 10.minutes.ago)
      create_list(:outboxer_message, 3, :dequeued, updated_at: 20.minutes.ago)
      create_list(:outboxer_message, 5, :publishing, updated_at: 30.minutes.ago)
      create_list(:outboxer_message, 4, :failed, updated_at: 40.minutes.ago)
    end

    describe '.report_metrics' do
      it 'sends metrics to statsd' do
        Messages.report_metrics(statsd: statsd, current_utc_time: current_time_utc)

        expect(statsd).to have_received(:gauge).with('outboxer.messages.queued.size', 2)
        expect(statsd).to have_received(:gauge).with('outboxer.messages.queued.latency',
          be_within(1).of(10.minutes.to_i))

        expect(statsd).to have_received(:gauge).with('outboxer.messages.dequeued.size', 3)
        expect(statsd).to have_received(:gauge).with('outboxer.messages.dequeued.latency',
          be_within(1).of(20.minutes.to_i))

        expect(statsd).to have_received(:gauge).with('outboxer.messages.publishing.size', 5)
        expect(statsd).to have_received(:gauge).with('outboxer.messages.publishing.latency',
          be_within(1).of(30.minutes.to_i))

        expect(statsd).to have_received(:gauge).with('outboxer.messages.failed.size', 4)
        expect(statsd).to have_received(:gauge).with('outboxer.messages.failed.latency',
          be_within(1).of(40.minutes.to_i))
      end
    end
  end
end
