require "open3"
require "timeout"

RSpec.describe "Outboxer StatsD (Datadog agent logs)" do
  before do
    system("docker restart datadog")
    sleep 2
  end

  it "emits expected statsd metrics" do
    Open3.popen3(
      {
        "RAILS_ENV" => "test",
        "STATSD_HOST" => "127.0.0.1",
        "STATSD_PORT" => "18125"
      },
      "ruby bin/statsd_publisher"
    ) do |_stdin, _stdout, _stderr, wait_thr|
      sleep 3

      if wait_thr.alive?
        Process.kill("TERM", wait_thr.pid)
      end

      wait_thr.value
    end

    logs = `docker logs datadog`

    expect(logs).to include("Processing metric sample")
    expect(logs).to include("outboxer.messages.count")
    expect(logs).to include("outboxer.messages.latency")
    expect(logs).to include("status:")
  end
end
