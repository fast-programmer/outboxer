require "rails_helper"

require_relative "../../app/models/application_record"
require_relative "../../app/models/event"
require_relative "../../app/models/outboxer_integration/test_started_event"
require_relative "../../app/models/outboxer_integration/test_completed_event"

RSpec.describe "bin/outboxer_publisher" do
  let(:test_id) { 999 }

  it "performs event job handler async" do
    Sidekiq::Testing.disable!

    OutboxerIntegration::TestStartedEvent.create!(body: { "test_id" => test_id })

    env = {
      "RAILS_ENV" => "test",
      "REDIS_URL" => "redis://localhost:6379/0"
    }

    outboxer_publisher_cmd = File.join(Dir.pwd, "bin", "outboxer_publisher")
    outboxer_publisher_pid = spawn(env, outboxer_publisher_cmd)

    sidekiq_cmd = "bundle exec sidekiq -r ./config/sidekiq.rb"
    sidekiq_pid = spawn(env, sidekiq_cmd)

    max_attempts = 10

    test_completed_event = nil

    max_attempts.times do |attempt|
      test_completed_event = OutboxerIntegration::TestCompletedEvent.last
      break if test_completed_event

      sleep 1

      Sidekiq.logger.warn "OutboxerIntegration::TestCompletedEvent not found. " \
        "Retrying (attempt #{attempt + 1}/#{max_attempts})..."
    end

    expect(test_completed_event.type).not_to be_nil
    expect(test_completed_event.body).to eql({ "test_id" => test_id })
    expect(test_completed_event.created_at).not_to be_nil
  ensure
    if sidekiq_pid
      Process.kill("TERM", sidekiq_pid)
      Process.wait(sidekiq_pid)
    end

    if outboxer_publisher_pid
      Process.kill("TERM", outboxer_publisher_pid)
      Process.wait(outboxer_publisher_pid)
    end

    Sidekiq::Testing.fake!
  end
end
