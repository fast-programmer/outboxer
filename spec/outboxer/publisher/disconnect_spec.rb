require 'spec_helper'

module Outboxer
  RSpec.describe Publisher do
    describe '.disconnect!' do
      context 'when successful' do
        it 'does not raise an error' do
          expect { Publisher.disconnect! }.not_to raise_error
        end

        it 'returns connected false' do
          Publisher.disconnect!

          expect(Publisher.connected?).to be false
        end
      end

      context 'when not successful' do
        before do
          allow(ActiveRecord::Base.connection_handler)
            .to receive(:clear_active_connections!).and_raise(ActiveRecord::ConnectionNotEstablished)
        end

        it 'raises a DisconnectError' do
          expect { Publisher.disconnect! }.to raise_error(Publisher::DisconnectError)
        end
      end
    end
  end
end
