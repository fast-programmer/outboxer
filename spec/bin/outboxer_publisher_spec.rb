require "rails_helper"

RSpec.describe "bin/outboxer_publisher" do
  let(:env) { { "RAILS_ENV" => "test" } }
  let(:publisher_cmd) { File.join(Dir.pwd, "bin", "outboxer_publisher") }

  let(:attempt) { 1 }
  let(:max_attempts) { 20 }
  let(:delay) { 1 }

  let(:messageable) { double("Event", id: 123, class: double(name: "Event")) }
  let!(:message) { Outboxer::Message.queue(messageable: messageable) }

  it "publishes message" do
    read_io, write_io = IO.pipe
    publisher_pid = spawn(env, "ruby", publisher_cmd, out: write_io, err: write_io)
    write_io.close

    output = +""
    attempt = 1

    while attempt <= max_attempts
      begin
        partial = read_io.read_nonblock(1024)
        output << partial if partial
      rescue IO::WaitReadable, EOFError
        # no output yet
      end

      break if output.match(/published message/)

      sleep delay
      warn "Outboxer published message not found. Retrying (attempt #{attempt}/#{max_attempts})..."
      attempt += 1
    end

    Process.kill("TERM", publisher_pid)
    Process.wait(publisher_pid)
    read_io.close

    expect(output).to match(
      "published message " \
      "id=#{message[:id]} "
    )
  end
end
