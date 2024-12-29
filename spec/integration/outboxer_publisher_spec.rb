require 'spec_helper'

require 'sidekiq'
require 'sidekiq/testing'

require File.join(Dir.pwd, 'app/models/event')
require File.join(Dir.pwd, 'app/models/outboxer_integration/test/started_event')
require File.join(Dir.pwd, 'app/models/outboxer_integration/test/completed_event')

RSpec.describe 'Outboxer e2e test' do
  let(:test_id) { rand(1_000) + 1 }

  it 'performs job handler async' do
    Sidekiq::Testing.disable!

    OutboxerIntegration::Test::StartedEvent.create!(
      body: {
        'test' => {
          'id' => test_id } })

    outboxer_publisher_env = {
      "OUTBOXER_ENV" => "test",
      "OUTBOXER_REDIS_URL" => "redis://localhost:6379/0" }
    outboxer_publisher_cmd = File.join(Dir.pwd, 'bin', 'outboxer_publisher')
    outboxer_publisher_pid = spawn(outboxer_publisher_env, outboxer_publisher_cmd)

    sidekiq_env = {
      "RAILS_ENV" => "test",
      "REDIS_URL" => "redis://localhost:6379/0" }
    sidekiq_cmd = "bundle exec sidekiq -c 10 -q default -r ./config/sidekiq.rb"
    sidekiq_pid = spawn(sidekiq_env, sidekiq_cmd)

    max_attempts = 10

    completed_event = nil

    max_attempts.times do |attempt|
      completed_event = OutboxerIntegration::Test::CompletedEvent.last
      break if completed_event

      sleep 1

      puts "OutboxerIntegration::Test::CompletedEvent not found. "\
        "Retrying (attempt #{attempt + 1}/#{max_attempts})..."
    end

    expect(completed_event.body['test']['id']).to eql(test_id)
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
