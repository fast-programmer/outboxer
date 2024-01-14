require 'spec_helper'

module Outboxer
  RSpec.describe Publisher do
    describe '.publish!' do
      let(:queue_max) { 1 }
      let(:threads_max) { 1 }
      let(:poll) { 1 }
      let(:logger) { instance_double(Logger, debug: true, error: true, fatal: true) }
      let(:kernel) { class_double(Kernel, sleep: nil) }

      let!(:message) do
        Models::Message.create!(
          outboxer_messageable_type: 'DummyType',
          outboxer_messageable_id: 1,
          status: Models::Message::STATUS[:unpublished])
      end

      context 'when message published successfully' do
        before do
          Publisher.publish!(
            threads_max: threads_max,
            queue_max: queue_max,
            poll: poll, logger: logger,
            kernel: kernel
          ) do |publishing_message|
            expect(publishing_message.outboxer_messageable_type).to eq('DummyType')
            expect(publishing_message.outboxer_messageable_id).to eq(1)
            expect(publishing_message.status).to eq(Models::Message::STATUS[:publishing])

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
              threads_max: threads_max,
              queue_max: queue_max,
              poll: poll,
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
              threads_max: threads_max,
              queue_max: queue_max,
              poll: poll,
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
              threads_max: threads_max,
              queue_max: queue_max,
              poll: poll,
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
              threads_max: threads_max,
              queue_max: queue_max,
              poll: poll,
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
