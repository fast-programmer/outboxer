require 'spec_helper'

module Outboxer
  RSpec.describe Message do
    describe '.backlog' do
      context 'when messageable argument provided' do
        let(:event) { double('Event', id: '1', class: double(name: 'Event')) }

        let!(:backlogged_message) { Message.backlog(messageable: event) }

        it 'creates model with backlogged status' do
          expect(backlogged_message[:id]).to eq(
            Models::Message.where(status: Models::Message::Status::BACKLOGGED).first.id)
        end
      end

      context 'when messageable_type and messageable_id arguments provided' do
        let!(:backlogged_message) do
          Message.backlog(messageable_type: 'Event', messageable_id: '1')
        end

        it 'creates model with backlogged status' do
          expect(backlogged_message[:id]).to eq(
            Models::Message.where(status: Models::Message::Status::BACKLOGGED).first.id)
        end
      end
    end
  end
end
