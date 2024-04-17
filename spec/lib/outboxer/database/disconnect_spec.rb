require 'spec_helper'

module Outboxer
  RSpec.describe Database do
    describe '.disconnect' do
      context 'when successful' do
        it 'does not raise an error' do
          expect { Database.disconnect(logger: nil) }.not_to raise_error
        end

        it 'returns connected false' do
          Database.disconnect(logger: nil)

          expect(Database.connected?).to be false
        end
      end

      context 'when not successful' do
        before do
          allow(ActiveRecord::Base.connection_handler)
            .to receive(:clear_active_connections!).and_raise(ActiveRecord::ConnectionNotEstablished)
        end

        it 'raises a DisconnectError' do
          expect { Database.disconnect(logger: nil) }.to raise_error(Database::DisconnectError)
        end
      end
    end
  end
end
