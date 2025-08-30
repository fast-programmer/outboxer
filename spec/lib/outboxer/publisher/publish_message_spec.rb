# rubocop:disable Layout/LineLength
require "rails_helper"

module Outboxer
  RSpec.describe Publisher do
    describe ".publish_message" do
      let(:poll_interval) { 1 }
      let(:tick_interval) { 0.1 }
      let(:logger) { instance_double(Logger, debug: true, error: true, fatal: true, info: true, level: 1) }
      let(:kernel) { Kernel }

      before do
        allow(logger).to receive(:level=)
      end

      context "when Publisher.terminate is called from within the block" do
        let!(:queued_message) { create(:outboxer_message, :queued, updated_at: 2.seconds.ago) }

        it "terminates the publisher" do
          Publisher.publish_message(
            poll_interval: poll_interval,
            tick_interval: tick_interval,
            logger: logger,
            kernel: kernel
          ) do |publisher, _message|
            Publisher.terminate(id: publisher[:id])
          end
        end
      end

      context "when sweeper deletes a message" do
        let!(:message_1) { create(:outboxer_message, :published, updated_at: 2.seconds.ago) }
        let!(:message_2) { create(:outboxer_message, :published, updated_at: 2.seconds.ago) }

        it "deletes the old published message" do
          publish_messages_thread = Thread.new do
            Publisher.publish_message(
              poll_interval: poll_interval,
              tick_interval: tick_interval,
              sweep_interval: 0.1,
              sweep_retention: 0.1,
              sweep_batch_size: 100,
              logger: logger,
              kernel: kernel
            ) do |_publisher, _message|
              # no op
            end
          end

          sleep 0.3

          ::Process.kill("TERM", ::Process.pid)

          publish_messages_thread.join

          expect(Models::Message.count).to be(0)
        end
      end

      context "when sweeper raises StandardError" do
        let!(:old_message) { create(:outboxer_message, :published, updated_at: 2.seconds.ago) }

        before do
          allow(Message).to receive(:delete_batch)
            .and_raise(StandardError, "sweep fail")
        end

        it "logs error" do
          publish_messages_thread = Thread.new do
            Publisher.publish_message(
              poll_interval: poll_interval,
              tick_interval: tick_interval,
              sweep_interval: 0.1,
              sweep_retention: 0.1,
              sweep_batch_size: 100,
              logger: logger,
              kernel: kernel
            ) do |_publisher, _message|
              # no op
            end
          end

          sleep 0.3
          ::Process.kill("TERM", ::Process.pid)
          publish_messages_thread.join

          expect(logger).to have_received(:error)
            .with(include("StandardError: sweep fail"))
            .at_least(:once)
        end

        it "does not delete the old message" do
          thread = Thread.new do
            Publisher.publish_message(
              poll_interval: poll_interval,
              tick_interval: tick_interval,
              sweep_interval: 0.1,
              sweep_retention: 1,
              sweep_batch_size: 1,
              logger: logger,
              kernel: kernel
            ) do |_publisher, message|
              # no op
            end
          end

          sleep 0.3
          ::Process.kill("TERM", ::Process.pid)
          thread.join

          expect(Models::Message.exists?(id: old_message.id)).to be(true)
        end
      end

      context "when sweeper raises critical error" do
        let!(:old_message) { create(:outboxer_message, :published, updated_at: 2.seconds.ago) }

        before do
          allow(Message).to receive(:delete_batch)
            .and_raise(NoMemoryError, "boom")

          thread = Thread.new do
            Publisher.publish_message(
              poll_interval: poll_interval,
              tick_interval: tick_interval,
              sweep_interval: 0.1,
              sweep_retention: 0.1,
              sweep_batch_size: 100,
              logger: logger,
              kernel: kernel
            ) do |_publisher, message|
              # no op
            end
          end

          sleep 0.3
          ::Process.kill("TERM", ::Process.pid)
          thread.join
        end

        it "logs fatal error" do
          expect(logger).to have_received(:fatal)
            .with(include("NoMemoryError: boom"))
        end

        it "does not delete the old message" do
          expect(Models::Message.exists?(id: old_message.id)).to be(true)
        end
      end

      context "when TTIN signal sent" do
        let!(:old_message) { create(:outboxer_message, :queued, updated_at: 2.seconds.ago) }

        it "dumps stack trace" do
          publish_messages_thread = Thread.new do
            Publisher.publish_message(
              poll_interval: poll_interval,
              tick_interval: tick_interval,
              logger: logger, kernel: kernel
            ) do |_publisher, _message|
              ::Process.kill("TTIN", ::Process.pid)
            end
          end

          sleep 1

          ::Process.kill("TERM", ::Process.pid)

          publish_messages_thread.join

          expect(logger)
            .to have_received(:info)
            .with(a_string_including("backtrace"))
            .at_least(:once)
        end
      end

      context "when stopped and resumed during message publishing" do
        let!(:queued_message) { create(:outboxer_message, :queued, updated_at: 2.seconds.ago) }

        it "stops and resumes the publishing process correctly" do
          Publisher.publish_message(
            poll_interval: poll_interval,
            tick_interval: tick_interval,
            logger: logger,
            kernel: kernel
          ) do |_publisher, _message|
            ::Process.kill("TSTP", ::Process.pid)
            sleep 0.5
            ::Process.kill("CONT", ::Process.pid)
            sleep 0.5
            ::Process.kill("TERM", ::Process.pid)
          end

          expect(Models::Message.published.count).to eq(1)
        end
      end

      context "when message published successfully" do
        let!(:queued_message) { create(:outboxer_message, :queued, updated_at: 2.seconds.ago) }

        it "sets the message to published" do
          Publisher.publish_message(
            poll_interval: poll_interval,
            tick_interval: tick_interval,
            logger: logger,
            kernel: kernel
          ) do |_publisher, message|
            expect(message[:id]).to eq(queued_message.id)
            expect(message[:messageable_type]).to eq(queued_message.messageable_type)
            expect(message[:messageable_id]).to eq(queued_message.messageable_id)

            ::Process.kill("TERM", ::Process.pid)
          end

          expect(Models::Message.published.count).to eq(1)
        end
      end

      context "when an error is raised in the block" do
        let!(:queued_message) { create(:outboxer_message, :queued, updated_at: 2.seconds.ago) }

        context "when a standard error is raised" do
          let(:standard_error) { StandardError.new("some error") }

          before do
            Publisher.publish_message(
              poll_interval: poll_interval,
              tick_interval: tick_interval,
              logger: logger,
              kernel: kernel
            ) do |_publisher, _message|
              ::Process.kill("TERM", ::Process.pid)

              raise standard_error
            end
          end

          it "changes publishing status to failed" do
            queued_message.reload

            expect(queued_message.status).to eq(Message::Status::FAILED)
          end

          it "logs errors" do
            expect(logger).to have_received(:error).with(
              a_string_matching(/^StandardError: some error/)).once
          end
        end

        context "when a critical error is raised" do
          let(:no_memory_error) { NoMemoryError.new }
          let!(:queued_message) { create(:outboxer_message, :queued, updated_at: 2.seconds.ago) }

          before do
            Publisher.publish_message(
              poll_interval: poll_interval,
              tick_interval: tick_interval,
              logger: logger,
              kernel: kernel
            ) do |_publisher, _message|
              raise no_memory_error
            end
          end

          it "changes publishing status to failed" do
            queued_message.reload

            expect(queued_message.status).to eq(Message::Status::FAILED)
          end

          it "logs errors" do
            expect(logger).to have_received(:fatal).with(
              a_string_matching("#{no_memory_error.class}: #{no_memory_error.message}")).once
          end
        end

        context "when buffer_messages raises a StandardError" do
          it "logs the error and continues processing" do
            call_count = 0

            allow(Publisher).to receive(:buffer_messages) do
              call_count += 1

              case call_count
              when 1
                raise StandardError, "queue error"
              else
                ::Process.kill("TERM", ::Process.pid)

                []
              end
            end

            expect(logger).to receive(:error).with(include("StandardError: queue error")).once

            Publisher.publish_message(
              poll_interval: poll_interval,
              tick_interval: tick_interval,
              logger: logger,
              kernel: kernel) do |publisher, messages|
                # no op
              end
          end
        end

        context "when buffer_messages raises an Exception" do
          it "logs the exception and shuts down" do
            allow(Publisher).to receive(:buffer_messages)
              .and_raise(NoMemoryError, "failed to allocate memory")

            expect(logger).to receive(:fatal)
              .with(include("NoMemoryError: failed to allocate memory"))
              .once

            Publisher.publish_message(
              poll_interval: poll_interval,
              tick_interval: tick_interval,
              logger: logger,
              kernel: kernel)
          end
        end
      end
    end
  end
end
# rubocop:enable Layout/LineLength
