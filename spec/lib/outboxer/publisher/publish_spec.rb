require 'spec_helper'

module Outboxer
  RSpec.describe Publisher do
    describe '.publish!' do
      let(:queue_size) { 1 }
      let(:thread_count) { 1 }
      let(:poll_interval) { 1 }
      let(:logger) { instance_double(Logger, debug: true, error: true, fatal: true, info: true) }
      let(:kernel) { class_double(Kernel, sleep: nil) }

      before do
        allow(logger).to receive(:level=)
      end

      let!(:message) do
        Models::Message.create!(
          outboxable_type: 'DummyType',
          outboxable_id: 1,
          status: Models::Message::Status::UNPUBLISHED)
      end

      context 'when message published successfully' do
        before do
          Publisher.publish!(
            thread_count: thread_count,
            queue_size: queue_size,
            poll_interval: poll_interval,
            logger: logger,
            kernel: kernel
          ) do |publishing_message|
            expect(publishing_message.outboxable_type).to eq('DummyType')
            expect(publishing_message.outboxable_id).to eq('1')
            expect(publishing_message.status).to eq(Models::Message::Status::PUBLISHING)

            Publisher.stop!
          end
        end

        it 'deletes existing message' do
          expect(Models::Message.count).to eq(0)
        end
      end

      context 'when an error is raised in the block' do
        context 'when a standard error is raised' do
          let(:standard_error) { StandardError.new('some error') }

          before do
            Publisher.publish!(
              thread_count: thread_count,
              queue_size: queue_size,
              poll_interval: poll_interval,
              logger: logger,
              kernel: kernel,
            ) do |publishing_message|
              Publisher.stop!

              raise standard_error
            end
          end

          it 'logs errors' do
            expect(logger).to have_received(:error).with(
              "Message processing failed for id: #{message.id}, error: #{standard_error.message}").once

            expect(logger).to have_received(:error).with(
              "#{standard_error.class.to_s}: #{standard_error.message}").once
          end
        end

        context 'when a critical error is raised' do
          let(:no_memory_error) { NoMemoryError.new }

          before do
            Publisher.publish!(
              thread_count: thread_count,
              queue_size: queue_size,
              poll_interval: poll_interval,
              logger: logger,
              kernel: kernel,
            ) do |publishing_message|
              Publisher.stop!

              raise no_memory_error
            end
          end

          it 'stops the publisher' do
            expect(Publisher.running?).to eq false
          end

          it 'logs errors' do
            expect(logger).to have_received(:error).with(
              "Message processing failed for id: #{message.id}, error: #{no_memory_error.message}").once

            expect(logger).to have_received(:fatal)
              .with("#{no_memory_error.class.to_s}: #{no_memory_error.message}").once
          end
        end
      end

      context 'when a error is raised in push_messages!' do
        context 'when standard error is raised' do
          before do
            allow(Publisher).to receive(:push_messages!) do
              Publisher.stop!

              raise StandardError, "Simulated Standard Error"
            end

            Publisher.publish!(
              thread_count: thread_count,
              queue_size: queue_size,
              poll_interval: poll_interval,
              logger: logger,
              kernel: kernel
            ) {}
          end

          it 'logs an error message' do
            expect(logger).to have_received(:error)
              .with("StandardError: Simulated Standard Error").once
          end
        end

        context 'when exception is raised' do
          let(:no_memory_error) { NoMemoryError.new }

          before do
            allow(Publisher).to receive(:push_messages!) do
              raise no_memory_error
            end

            Publisher.publish!(
              thread_count: thread_count,
              queue_size: queue_size,
              poll_interval: poll_interval,
              logger: logger,
              kernel: kernel
            ) {}
          end

          it 'stops the publisher' do
            expect(Publisher.running?).to eq false
          end

          it 'logs an error message' do
            expect(logger).to have_received(:fatal)
              .with("#{no_memory_error.class.to_s}: #{no_memory_error.message}").once
          end
        end
      end
    end
  end
end
