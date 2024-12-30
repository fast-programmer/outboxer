require 'spec_helper'

require 'sidekiq'
require 'sidekiq/testing'

require File.join(Dir.pwd, 'app/models/event')
require File.join(Dir.pwd, 'app/models/outboxer_integration/test.rb')
require File.join(Dir.pwd, 'app/models/outboxer_integration/test_started_event')
require File.join(Dir.pwd, 'app/models/outboxer_integration/test_completed_event')

RSpec.describe 'bin/outboxer_publisher' do
  it 'performs event job handler async' do
    Sidekiq::Testing.disable!

    user_id = rand(1_000) + 1
    tenant_id = rand(1_000) + 1

    test, _events = OutboxerIntegration::Test.start(user_id: user_id, tenant_id: tenant_id)

    outboxer_publisher_env = {
      "RAILS_ENV" => "test",
      "REDIS_URL" => "redis://localhost:6379/0" }
    outboxer_publisher_cmd = File.join(Dir.pwd, 'bin', 'outboxer_publisher')
    outboxer_publisher_pid = spawn(outboxer_publisher_env, outboxer_publisher_cmd)

    sidekiq_env = {
      "RAILS_ENV" => "test",
      "REDIS_URL" => "redis://localhost:6379/0" }
    sidekiq_cmd = "bundle exec sidekiq -c 10 -q default -r ./config/sidekiq.rb"
    sidekiq_pid = spawn(sidekiq_env, sidekiq_cmd)

    max_attempts = 10

    test_completed_event = nil

    max_attempts.times do |attempt|
      test = OutboxerIntegration::Test.find(test[:id])
      test_completed_event = OutboxerIntegration::TestCompletedEvent.last
      break if test_completed_event && (test.events.last == test_completed_event)

      sleep 1

      Sidekiq.logger.warn "OutboxerIntegration::TestCompletedEvent not found. "\
        "Retrying (attempt #{attempt + 1}/#{max_attempts})..."
    end

    expect(test_completed_event.body['test']['id']).to eql(test.id)
  ensure
    if sidekiq_pid
      Process.kill("TERM", sidekiq_pid)
      Process.wait(sidekiq_pid)
    end

    if outboxer_publisher_pid
      Process.kill('TERM', outboxer_publisher_pid)
      Process.wait(outboxer_publisher_pid)
    end

    Sidekiq::Testing.fake!
  end
end
