require 'spec_helper'
require 'sidekiq'

require_relative '../../../app/jobs/outboxer_integration/publish_message_job'
require_relative '../../../app/jobs/outboxer_integration/test_started_job'

require 'sidekiq/testing'

module OutboxerIntegration
  RSpec.describe PublishMessageJob, type: :job do
    describe '#perform' do
      context 'when OutboxerIntegration::TestStartedEvent' do
        let(:args) do
          {
            'messageable_type' => 'OutboxerIntegration::TestStartedEvent',
            'messageable_id' => '123'
          }
        end

        it 'performs OutboxerIntegration::TestStartedJob async and no other jobs' do
          PublishMessageJob.new.perform(args)

          expect(OutboxerIntegration::TestStartedJob.jobs).to match([
            hash_including('args' => [include('event_id' => '123')])
          ])
        end
      end

      context 'with invalid messageable_type' do
        let(:args) do
          {
            'messageable_type' => 'Wrong::Format::Test',
            'messageable_id' => '123'
          }
        end

        it 'does not enqueue any job' do
          expect {
            PublishMessageJob.new.perform(args)
          }.not_to change { Sidekiq::Worker.jobs.size }
        end
      end

      context 'when job class does not exist' do
        let(:args) do
          {
            'messageable_type' => 'OutboxerIntegration::InvoiceNonexistentEvent',
            'messageable_id' => '123'
          }
        end

        it 'does not enqueue any job and handles the error silently' do
          allow_any_instance_of(String).to receive(:constantize)
            .and_raise(NameError.new("uninitialized constant"))

          expect {
            PublishMessageJob.new.perform(args)
          }.not_to change { Sidekiq::Worker.jobs.size }
        end
      end
    end
  end
end
