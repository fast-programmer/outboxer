require 'spec_helper'

RSpec.describe Outboxer::Messageable, type: :model do
  before(:each) do
    ActiveRecord::Schema.define do
      create_table :events, force: true do |_t|
      end
    end

    class Event < ActiveRecord::Base
      include Outboxer::Messageable
    end
  end

  after(:each) do
    if ActiveRecord::Base.connection.table_exists?('events')
      ActiveRecord::Migration.drop_table('events')
    end

    Object.send(:remove_const, :Event) if Object.const_defined?(:Event)
  end

  context 'when model created' do
    let(:event) { Event.create! }
    let(:outboxer_message) { event.outboxer_message }

    it 'creates outboxer message' do
      expect(outboxer_message.status).to eq(Outboxer::Models::Message::Status::UNPUBLISHED)
      expect(outboxer_message.messageable_type).to eq(event.class.to_s)
      expect(outboxer_message.messageable_id).to eq(event.id)
      expect(outboxer_message.created_at).to be_present
      expect(outboxer_message.updated_at).to be_present
    end
  end
end
