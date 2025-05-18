# rubocop:disable Layout/LineLength
require "rails_helper"

module Outboxer
  RSpec.describe Publisher do
    describe ".publish_messages" do
      let(:buffer_size) { 1 }
      let(:poll_interval) { 1 }
      let(:tick_interval) { 0.1 }
      let(:logger) { instance_double(Logger, debug: true, error: true, fatal: true, info: true, level: 1) }
      let(:kernel) { class_double(Kernel, sleep: nil) }

      before do
        allow(logger).to receive(:level=)
      end

      context "when Publisher.terminate is called from within the block" do
        let!(:queued_message) { create(:outboxer_message, :queued, updated_at: 2.seconds.ago) }

        it "terminates the publisher" do
          Publisher.publish_messages(
            buffer_size: buffer_size,
            poll_interval: poll_interval,
            tick_interval: tick_interval,
            logger: logger,
            kernel: kernel
          ) do |publisher, _messages|
            Publisher.terminate(id: publisher[:id])
          end
        end
      end

      context "when sweeper deletes a message" do
        let!(:message_1) { create(:outboxer_message, :published, updated_at: 2.seconds.ago) }
        let!(:message_2) { create(:outboxer_message, :published, updated_at: 2.seconds.ago) }

        it "deletes the old published message" do
          publish_messages_thread = Thread.new do
            Publisher.publish_messages(
              buffer_size: buffer_size,
              poll_interval: poll_interval,
              tick_interval: tick_interval,
              sweep_interval: 0.1,
              sweep_retention: 0.1,
              sweep_batch_size: 100,
              logger: logger,
              kernel: kernel
            ) do |_publisher, _messages| # no op
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
            Publisher.publish_messages(
              buffer_size: buffer_size,
              poll_interval: poll_interval,
              tick_interval: tick_interval,
              sweep_interval: 0.1,
              sweep_retention: 0.1,
              sweep_batch_size: 100,
              logger: logger,
              kernel: kernel
            ) do |_publisher, _messages| # no op
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
            Publisher.publish_messages(
              buffer_size: buffer_size,
              poll_interval: poll_interval,
              tick_interval: tick_interval,
              sweep_interval: 0.1,
              sweep_retention: 1,
              sweep_batch_size: 1,
              logger: logger,
              kernel: kernel
            ) do |_publisher, _messages| # no op
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
            Publisher.publish_messages(
              buffer_size: buffer_size,
              poll_interval: poll_interval,
              tick_interval: tick_interval,
              sweep_interval: 0.1,
              sweep_retention: 0.1,
              sweep_batch_size: 100,
              logger: logger,
              kernel: kernel
            ) do |_publisher, _messages| # no op
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
            Publisher.publish_messages(
              buffer_size: buffer_size,
              poll_interval: poll_interval,
              tick_interval: tick_interval,
              logger: logger, kernel: kernel) do |_publisher, _messages|
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
        it "stops and resumes the publishing process correctly" do
          publish_messages_thread = Thread.new do
            Publisher.publish_messages(
              buffer_size: buffer_size,
              poll_interval: poll_interval,
              tick_interval: tick_interval,
              logger: logger,
              kernel: kernel) do |_publisher, _messages|
              ::Process.kill("TSTP", ::Process.pid)
            end
          end
          sleep 2

          ::Process.kill("CONT", ::Process.pid)
          sleep 1

          ::Process.kill("TERM", ::Process.pid)

          publish_messages_thread.join
        end
      end

      context "when message published successfully" do
        let!(:queued_message) { create(:outboxer_message, :queued, updated_at: 2.seconds.ago) }

        it "sets the message to published" do
          Publisher.publish_messages(
            buffer_size: buffer_size,
            poll_interval: poll_interval,
            tick_interval: tick_interval,
            logger: logger,
            kernel: kernel) do |_publisher, messages|
            message = messages.first

            expect(message[:id]).to eq(queued_message.id)
            expect(message[:messageable_type]).to eq(queued_message.messageable_type)
            expect(message[:messageable_id]).to eq(queued_message.messageable_id)
            expect(message[:status]).to eq(Message::Status::PUBLISHING)

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
            Publisher.publish_messages(
              buffer_size: buffer_size,
              poll_interval: poll_interval,
              tick_interval: tick_interval,
              logger: logger,
              kernel: kernel) do |_publisher, _message|
              ::Process.kill("TERM", ::Process.pid)

              raise standard_error
            end
          end

          it "sets message to failed" do
            queued_message.reload

            expect(queued_message.status).to eq(Message::Status::FAILED)
            expect(queued_message.exceptions.count).to eq(1)
            expect(queued_message.exceptions[0].class_name).to eq(standard_error.class.name)
            expect(queued_message.exceptions[0].message_text).to eq(standard_error.message)
            expect(queued_message.exceptions[0].created_at).not_to be_nil

            expect(queued_message.exceptions[0].frames[0].index).to eq(0)

            expect(queued_message.exceptions[0].frames[0].text).to match(
              /outboxer\/publisher\/publish_messages_spec.rb:\d+:in `block \(6 levels\) in <module:Outboxer>'/)
          end

          it "logs errors" do
            expect(logger).to have_received(:error).with(
              a_string_matching(/^StandardError: some error/)).once

            expect(logger).to have_received(:debug).with(
              a_string_matching("failed to publish message id=#{queued_message.id} " \
                "messageable=#{queued_message[:messageable_type]}::#{queued_message[:messageable_id]}")).once
          end
        end

        context "when a critical error is raised" do
          let(:no_memory_error) { NoMemoryError.new }
          let!(:queued_message) { create(:outboxer_message, :queued, updated_at: 2.seconds.ago) }

          before do
            Publisher.publish_messages(
              buffer_size: buffer_size,
              poll_interval: poll_interval,
              tick_interval: tick_interval,
              logger: logger,
              kernel: kernel) do |_publisher, _buffer_sized_message|
              raise no_memory_error
            end
          end

          it "sets message to failed" do
            queued_message.reload

            expect(queued_message.status).to eq(Message::Status::FAILED)
            expect(queued_message.exceptions.count).to eq(1)
            expect(queued_message.exceptions[0].class_name).to eq(no_memory_error.class.name)
            expect(queued_message.exceptions[0].message_text).to eq(no_memory_error.message)
            expect(queued_message.exceptions[0].created_at).not_to be_nil

            expect(queued_message.exceptions[0].frames[0].index).to eq(0)
            expect(queued_message.exceptions[0].frames[0].text).to match(
              /outboxer\/publisher\/publish_messages_spec.rb:\d+:in `block \(6 levels\) in <module:Outboxer>'/)
          end

          it "logs errors" do
            expect(logger).to have_received(:debug).with(
              a_string_matching("failed to publish message id=#{queued_message.id} " \
                "messageable=#{queued_message[:messageable_type]}::#{queued_message[:messageable_id]}")).once

            expect(logger).to have_received(:fatal).with(
              a_string_matching("#{no_memory_error.class}: #{no_memory_error.message}")).once
          end
        end

        context "when Message.buffer raises a StandardError" do
          it "logs the error and continues processing" do
            call_count = 0

            allow(Message).to receive(:buffer) do
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

            Publisher.publish_messages(
              buffer_size: buffer_size,
              poll_interval: poll_interval,
              tick_interval: tick_interval,
              logger: logger,
              kernel: kernel)
          end
        end

        context "when Message.buffer raises an Exception" do
          it "logs the exception and shuts down" do
            allow(Message).to receive(:buffer)
              .and_raise(NoMemoryError, "failed to allocate memory")

            expect(logger).to receive(:fatal)
              .with(include("NoMemoryError: failed to allocate memory"))
              .once

            Publisher.publish_messages(
              buffer_size: buffer_size,
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
