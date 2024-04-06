require 'spec_helper'

module Outboxer
  RSpec.describe Message do
    describe '.backlog' do
      let!(:backlogged_message) do
        Message.backlog(messageable_type: 'Event', messageable_id: '1')
      end

      it 'returns backlogged message' do
        expect(backlogged_message['id']).to eq(Models::Message.backlogged.first.id)
      end
    end
  end
end
