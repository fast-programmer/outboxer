require 'spec_helper'

module Outboxer
  RSpec.describe SingleThreadedPublisher do
    describe '.sleep' do
      let(:duration) { 5 }
      let(:start_time) { Time.now }
      let(:tick_interval) { 1 }

      let(:logger) { instance_double(Logger, info: true, debug: true, error: true, fatal: true) }
      let(:kernel) { class_double(Kernel) }
      let(:time) { class_double(Time) }

      context 'when @publishing is true' do
        before do
          SingleThreadedPublisher.instance_variable_set(:@publishing, true)
        end

        context 'when time < duration' do
          it 'sleeps poll interval' do
            allow(time).to receive(:now).and_return(
              start_time + (tick_interval * 1),
              start_time + (tick_interval * 2),
              start_time + (tick_interval * 3),
              start_time + (tick_interval * 4))

            SingleThreadedPublisher.sleep(
              duration, start_time: start_time, tick_interval: tick_interval,
              time: time, kernel: kernel)

            expect(kernel).to have_received(:sleep).with(1).exactly(4).times
          end
        end

        context 'when time = duration' do
          it 'does not sleep poll interval' do
            allow(time).to receive(:now).and_return(start_time, start_time + duration)

            SingleThreadedPublisher.instance_variable_set(:@publishing, true)

            SingleThreadedPublisher.sleep(duration, poll_interval: poll_interval, start_time: start_time, time: time, kernel: kernel)
          end
        end

        context 'when time > duration' do
          it 'does not sleep poll interval' do
            allow(time).to receive(:now).and_return(start_time, start_time + duration + 0.1)
            SingleThreadedPublisher.instance_variable_set(:@publishing, true)

            SingleThreadedPublisher.sleep(duration, poll_interval: poll_interval, start_time: start_time, time: time, kernel: kernel)

            expect(kernel).not_to have_received(:sleep)

            SingleThreadedPublisher.instance_variable_set(:@publishing, false) # Resetting
          end
        end
      end

      context 'when @publishing is false' do
        context 'when time < duration' do
          it 'does not sleep poll interval' do
            allow(time).to receive(:now).and_return(start_time, start_time + 0.2)
            SingleThreadedPublisher.instance_variable_set(:@publishing, false)

            SingleThreadedPublisher.sleep(duration, poll_interval: poll_interval, start_time: start_time, time: time, kernel: kernel)

            expect(kernel).not_to have_received(:sleep)
          end
        end

        context 'when time = duration' do
          it 'does not sleep poll interval' do
            allow(time).to receive(:now).and_return(start_time, start_time + duration)
            SingleThreadedPublisher.instance_variable_set(:@publishing, false)

            SingleThreadedPublisher.sleep(duration, poll_interval: poll_interval, start_time: start_time, time: time, kernel: kernel)

            expect(kernel).not_to have_received(:sleep)
          end
        end

        context 'when time > duration' do
          it 'does not sleep poll interval' do
            allow(time).to receive(:now).and_return(start_time, start_time + duration + 0.1)
            SingleThreadedPublisher.instance_variable_set(:@publishing, false)

            SingleThreadedPublisher.sleep(duration, poll_interval: poll_interval, start_time: start_time, time: time, kernel: kernel)

            expect(kernel).not_to have_received(:sleep)
          end
        end
      end
    end
  end
end
