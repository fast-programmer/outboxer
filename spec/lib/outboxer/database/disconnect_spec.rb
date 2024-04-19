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
    end
  end
end
