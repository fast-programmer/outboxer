require "rails_helper"

RSpec.describe "bin/outboxer_publisher" do
  let(:env) { { "RAILS_ENV" => "test" } }
  let(:publisher_cmd) { File.join(Dir.pwd, "bin", "outboxer_publisher") }
  let!(:publisher_pid) { spawn(env, "ruby", publisher_cmd) }

  let(:messageable) { double("Event", id: 123, class: double(name: "Event")) }
  let!(:message) { Outboxer::Message.queue(messageable: messageable) }

  let(:max_attempts) { 10 }
  let(:delay) { 1 }

  it "publishes message" do
    attempt = 1

    was_published = Outboxer::Message
      .list(status: :published)
      .fetch(:messages)
      .any? { |published_message| published_message[:id] == message[:id] }

    while (attempt <= max_attempts) && !was_published
      warn "Outboxer message not published yet. Retrying (#{attempt}/#{max_attempts})..."
      sleep delay
      attempt += 1

      was_published = Outboxer::Message
        .list(status: :published)
        .fetch(:messages)
        .any? { |published_message| published_message[:id] == message[:id] }
    end

    Process.kill("TERM", publisher_pid)
    Process.wait(publisher_pid)

    expect(was_published).to be true
  end
end
