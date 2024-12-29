require 'spec_helper'
require 'sidekiq'

require_relative '../../../../app/jobs/outboxer_integration/message/publish_job'
require_relative '../../../../app/jobs/outboxer_integration/test/started_job'

require 'sidekiq/testing'

module OutboxerIntegration
  module Message
    RSpec.describe PublishJob, type: :job do
      describe '#perform' do
        context 'when OutboxerIntegration::Test::StartedEvent' do
          let(:args) do
            {
              'messageable_type' => 'OutboxerIntegration::Test::StartedEvent',
              'messageable_id' => '123'
            }
          end

          it 'performs OutboxerIntegration::Test::StartedJob async' do
            PublishJob.new.perform(args)

            expect(OutboxerIntegration::Test::StartedJob.jobs).to match([
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

          it 'does not raise an error' do
            expect {
              PublishJob.new.perform(args)
            }.not_to raise_error
          end
        end

        context 'when job class does not exist' do
          let(:args) do
            {
              'messageable_type' => 'OutboxerIntegration::Invoice::NonexistentEvent',
              'messageable_id' => '123'
            }
          end

          it 'does not raise an error' do
            allow_any_instance_of(String)
              .to receive(:constantize)
              .and_raise(NameError.new("uninitialized constant"))

            expect {
              PublishJob.new.perform(args)
            }.not_to raise_error
          end
        end
      end
    end
  end
end
