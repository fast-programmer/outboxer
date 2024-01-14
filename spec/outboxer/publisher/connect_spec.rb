require 'spec_helper'

module Outboxer
  RSpec.describe Publisher do
    describe '.connect!' do
      let(:db_config) do
        {
          'adapter' => 'postgresql',
          'username' => `whoami`.strip,
          'database' => 'outboxer_test'
        }
      end

      context 'when connecting to the database' do
        it 'establishes a connection without errors' do
          expect { Publisher.connect!(db_config: db_config) }.not_to raise_error
        end

        xit 'actually connects to the database' do
          Publisher.connect!(db_config: db_config)

          expect(ActiveRecord::Base.connected?).to be true
        end
      end
    end
  end
end
