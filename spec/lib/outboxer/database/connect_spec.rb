require 'spec_helper'

module Outboxer
  RSpec.describe Database do
    describe '.connect' do
      before(:each) { Database.disconnect(logger: nil) }

      after(:all) do
        config = Database.config(environment: 'test')
        Database.connect(config: config, logger: nil)
      end

      context 'when db config not valid' do
        let(:config) do
          {
            'adapter' => 'postgresql',
            'username' => 'bad',
            'database' => 'outboxer_test'
          }
        end

        it 'establishes a connection without errors' do
          expect do
            Database.connect(config: config, logger: nil)
          end.to raise_error(Database::ConnectError)
        end

        it 'does not connect to the database' do
          begin
            Database.connect(config: config, logger: nil)
          rescue Database::ConnectError
            # ignore
          end

          expect(Database.connected?).to be false
        end
      end

      context 'when db config valid' do
        let(:config) { Database.config(environment: 'test') }

        it 'establishes a connection without errors' do
          expect { Database.connect(config: config, logger: nil) }.not_to raise_error
        end

        it 'actually connects to the database' do
          Database.connect(config: config, logger: nil)

          expect(Database.connected?).to be true
        end
      end
    end
  end
end
