require 'spec_helper'

module Outboxer
  RSpec.describe Publisher do
    describe '.publish' do
      let(:buffer_size) { 1 }
      let(:poll_interval) { 1 }
      let(:concurrency) { 1 }
      let(:logger) { instance_double(Logger, debug: true, error: true, fatal: true, info: true) }
      let(:kernel) { class_double(Kernel, sleep: nil) }

      before do
        allow(logger).to receive(:level=)
      end

      let!(:queued_message) { create(:outboxer_message, :queued) }

      context 'when message published successfully' do
        it 'deletes existing message' do
          Publisher.publish(
            buffer_size: buffer_size,
            poll_interval: poll_interval,
            concurrency: concurrency,
            logger: logger,
            kernel: kernel
          ) do |message|
            expect(message[:id]).to eq(queued_message.id)
            expect(message[:messageable_type]).to eq(queued_message.messageable_type)
            expect(message[:messageable_id]).to eq(queued_message.messageable_id)
            expect(message[:status]).to eq(Models::Message::Status::PUBLISHING)

            Publisher.stop
          end

          expect(Models::Message.published.count).to eq(1)
        end
      end

      context 'when an error is raised in the block' do
        context 'when a standard error is raised' do
          let(:standard_error) { StandardError.new('some error') }

          before do
            Publisher.publish(
              buffer_size: buffer_size,
              poll_interval: poll_interval,
              concurrency: concurrency,
              logger: logger,
              kernel: kernel
            ) do |message|
              Publisher.stop

              raise standard_error
            end
          end

          it 'sets message to failed' do
            queued_message.reload

            expect(queued_message.status).to eq(Models::Message::Status::FAILED)

            expect(queued_message.exceptions.count).to eq(1)
            expect(queued_message.exceptions[0].class_name).to eq(standard_error.class.name)
            expect(queued_message.exceptions[0].message_text).to eq(standard_error.message)
            expect(queued_message.exceptions[0].created_at).not_to be_nil

            expect(queued_message.exceptions[0].frames.count).to eq(4)
            expect(queued_message.exceptions[0].frames[0].index).to eq(0)

            expect(queued_message.exceptions[0].frames[0].text).to match(
              /outboxer\/publisher\/publish_spec.rb:\d+:in `block \(6 levels\) in <module:Outboxer>'/)
          end

          it 'logs errors' do
            expect(logger).to have_received(:error).with(
              a_string_matching(/^StandardError: some error/)
            ).once

            expect(logger).to have_received(:error).with(
              a_string_matching("Failed to publish message #{queued_message.id} for " \
                "#{queued_message[:messageable_type]}::#{queued_message[:messageable_id]}")
            ).once
          end
        end

        context 'when a critical error is raised' do
          let(:no_memory_error) { NoMemoryError.new }

          before do
            Publisher.publish(
              buffer_size: buffer_size,
              poll_interval: poll_interval,
              concurrency: concurrency,
              logger: logger,
              kernel: kernel
            ) do |dequeued_message|
              Publisher.stop

              raise no_memory_error
            end
          end

          it 'sets message to failed' do
            queued_message.reload

            expect(queued_message.status).to eq(Models::Message::Status::FAILED)

            expect(queued_message.exceptions.count).to eq(1)
            expect(queued_message.exceptions[0].class_name).to eq(no_memory_error.class.name)
            expect(queued_message.exceptions[0].message_text).to eq(no_memory_error.message)
            expect(queued_message.exceptions[0].created_at).not_to be_nil

            expect(queued_message.exceptions[0].frames.count).to eq(4)
            expect(queued_message.exceptions[0].frames[0].index).to eq(0)
            expect(queued_message.exceptions[0].frames[0].text).to match(
              /outboxer\/publisher\/publish_spec.rb:\d+:in `block \(6 levels\) in <module:Outboxer>'/)
          end

          it 'logs errors' do
            expect(logger).to have_received(:error).with(
              a_string_matching("Failed to publish message #{queued_message.id} for " \
                "#{queued_message[:messageable_type]}::#{queued_message[:messageable_id]}")
            ).once

            expect(logger).to have_received(:fatal).with(
              a_string_matching("#{no_memory_error.class.to_s}: #{no_memory_error.message}")
            ).once
          end
        end

        context 'when Messages.dequeue raises a StandardError' do
          it 'logs the error and continues processing' do
            call_count = 0

            allow(Messages).to receive(:dequeue) do
              call_count += 1

              case call_count
              when 1
                raise StandardError, 'queue error'
              else
                Publisher.stop

                []
              end
            end

            expect(logger).to receive(:error).with(include('StandardError: queue error')).once

            Publisher.publish(
              buffer_size: buffer_size,
              concurrency: concurrency,
              poll_interval: poll_interval,
              logger: logger,
              kernel: kernel
            )
          end
        end

        context 'when Messages.dequeue raises an Exception' do
          it 'logs the exception and shuts down' do
            allow(Messages).to receive(:dequeue)
              .and_raise(NoMemoryError, 'failed to allocate memory')

            expect(logger).to receive(:fatal)
              .with(include('NoMemoryError: failed to allocate memory'))
              .once

            Publisher.publish(
              buffer_size: buffer_size,
              poll_interval: poll_interval,
              concurrency: concurrency,
              logger: logger,
              kernel: kernel)
          end
        end
      end
    end
  end
end
