require 'spec_helper'
require 'statsd-ruby'
require 'active_record'
require 'socket'

module Outboxer
  RSpec.describe Messages do
    let(:statsd) { instance_double(::Statsd) }
    let(:current_time_utc) { Time.now.utc }
    let(:interval) { 30 }
    let(:tags) { ['env:test'] }

    before do
      allow(statsd).to receive(:gauge)
      allow(statsd).to receive(:batch).and_yield(statsd)
    end

    before do
      create_list(:outboxer_message, 2, :queued)
      create_list(:outboxer_message, 3, :dequeued)
      create_list(:outboxer_message, 5, :publishing)
      create_list(:outboxer_message, 4, :failed)
    end

    describe '.log_metrics' do
      context 'when lock record exists' do
        let!(:lock) do
          create(:outboxer_locks, key: 'messages/log_metrics', updated_at: current_time_utc - interval - 1)
        end

        context 'when lock record available' do
          context 'when metrics have not been updated within interval' do
            it 'sends metrics to statsd' do
              Messages.log_metrics(
                statsd: statsd,
                interval: interval,
                tags: tags,
                current_time_utc: current_time_utc)

              expect(statsd).to have_received(:gauge).with('outboxer.messages.queued.count', 2)
              # expect(statsd).to have_received(:gauge).with('outboxer.messages.queued.latency')
              expect(statsd).to have_received(:gauge).with('outboxer.messages.dequeued.count', 3)
              # expect(statsd).to have_received(:gauge).with('outboxer.messages.dequeued.latency')
              expect(statsd).to have_received(:gauge).with('outboxer.messages.publishing.count', 5)
              # expect(statsd).to have_received(:gauge).with('outboxer.messages.publishing.latency')
              expect(statsd).to have_received(:gauge).with('outboxer.messages.failed.count', 1)
              # expect(statsd).to have_received(:gauge).with('outboxer.messages.failed.latency')
            end

            it 'updates lock record' do
              expect do
                Messages.log_metrics(statsd: statsd, interval: interval, current_time_utc: current_time_utc)
              end.to change { lock.reload.updated_at.utc }.to(current_time_utc)
            end
          end

          context 'when lock has been updated within interval' do
            let!(:lock) do
              create(:outboxer_locks,
                key: 'messages/log_metrics',
                updated_at: current_time_utc - interval + 1)
            end

            it 'does not send metrics to statsd' do
              Messages.log_metrics(statsd: statsd, interval: interval, current_time_utc: current_time_utc)

              expect(statsd).not_to have_received(:gauge)
            end

            it 'does not update lock record' do
              expect do
                Messages.log_metrics(statsd: statsd, interval: interval, current_time_utc: current_time_utc)
              end.not_to change { lock.reload.updated_at }
            end
          end
        end

        context 'when lock record not available' do
          before do
            allow(Models::Lock).to receive(:lock).with('FOR UPDATE NOWAIT').and_return(Models::Lock)
            allow(Models::Lock).to receive(:find_by!).with(key: 'messages/log_metrics').and_raise(ActiveRecord::LockWaitTimeout)
          end

          it 'does not send metrics to statsd' do
            Messages.log_metrics(statsd: statsd, interval: interval, current_time_utc: current_time_utc)

            expect(statsd).not_to have_received(:gauge)
          end

          it 'does not update lock record' do
            expect do
              Messages.log_metrics(statsd: statsd, interval: interval, current_time_utc: current_time_utc)
            end.not_to change { lock.reload.updated_at }
          end
        end
      end

      context 'when lock record does not exist' do
        # before do
        #   allow(Models::Lock).to receive(:lock).with('FOR UPDATE NOWAIT').and_return(Models::Lock)
        #   allow(Models::Lock).to receive(:find_by!).with(key: 'messages/log_metrics').and_raise(ActiveRecord::RecordNotFound)
        # end

        context 'when metrics record created' do
          context 'when lock record available' do
            context 'when metrics have not been updated within interval' do
              it 'sends metrics to statsd' do
                Messages.log_metrics(statsd: statsd, interval: interval, current_time_utc: current_time_utc)

                expect(statsd).to have_received(:gauge).with('outboxer.messages.queued.count', 2)
                # expect(statsd).to have_received(:gauge).with('outboxer.messages.queued.latency')
                expect(statsd).to have_received(:gauge).with('outboxer.messages.dequeued.count', 3)
                # expect(statsd).to have_received(:gauge).with('outboxer.messages.dequeued.latency')
                expect(statsd).to have_received(:gauge).with('outboxer.messages.publishing.count', 5)
                # expect(statsd).to have_received(:gauge).with('outboxer.messages.publishing.latency')
                expect(statsd).to have_received(:gauge).with('outboxer.messages.failed.count', 1)
                # expect(statsd).to have_received(:gauge).with('outboxer.messages.failed.latency')
              end

              it 'updates lock record' do
                expect do
                  Messages.log_metrics(statsd: statsd, interval: interval, current_time_utc: current_time_utc)
                end.to change { lock.reload.updated_at }.to(current_time_utc)
              end
            end

            context 'when lock has been updated within interval' do
              let!(:lock) { create(:outboxer_locks, key: 'messages/log_metrics', updated_at: current_time_utc - interval + 1) }

              it 'does not send metrics to statsd' do
                Messages.log_metrics(statsd: statsd, interval: interval, current_time_utc: current_time_utc)

                expect(statsd).not_to have_received(:gauge)
              end

              it 'does not update metrics record' do
                expect {
                  described_class.log(statsd: statsd, interval: interval, current_time: current_time)
                }.not_to raise_error
              end
            end
          end

          context 'when metrics record not available' do
            it 'does not send metrics to statsd' do
              described_class.log(statsd: statsd, interval: interval, current_time: current_time)

              expect(statsd).not_to have_received(:gauge)
            end

            it 'does not update metrics record' do
              expect {
                described_class.log(statsd: statsd, interval: interval, current_time: current_time)
              }.not_to raise_error
            end
          end
        end

        context 'when metrics record not unique' do
          before do
            allow(Models::Metrics).to receive(:lock).with('FOR UPDATE NOWAIT').and_raise(ActiveRecord::RecordNotUnique)
          end

          it 'does not send metrics to statsd' do
            described_class.log(statsd: statsd, interval: interval, current_time: current_time)

            expect(statsd).not_to have_received(:gauge)
          end

          it 'does not update metrics record' do
            expect {
              described_class.log(statsd: statsd, interval: interval, current_time: current_time)
            }.not_to raise_error
          end
        end
      end
    end
  end
end
