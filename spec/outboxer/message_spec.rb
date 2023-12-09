require "spec_helper"
require 'pry-byebug'

require_relative "../../generators/outboxer/templates/migrations/create_outboxer_messages"
require_relative "../../generators/outboxer/templates/migrations/create_outboxer_exceptions"

# psql -d postgres
# CREATE USER outboxer_tester WITH PASSWORD 'outboxer_tester';
# CREATE DATABASE outboxer_test;
# GRANT ALL PRIVILEGES ON DATABASE outboxer_test TO outboxer_tester;

# rubocop:disable Lint/ConstantDefinitionInBlock

# ActiveRecord::Base.logger = Logger.new($stdout)

RSpec.describe Outboxer::Message do
  before(:each) do
    # ActiveRecord::Base.logger = Logger.new(STDOUT)

    ActiveRecord::Base.establish_connection(
      host: "localhost",
      adapter: "postgresql",
      database: "outboxer_test",
      username: "outboxer_tester",
      password: "outboxer_password")

    existing_tables = %i[outboxer_exceptions outboxer_messages events accounting_invoices].select do |table|
      ActiveRecord::Base.connection.table_exists?(table)
    end

    existing_tables.each do |existing_table|
      ActiveRecord::Migration.drop_table(existing_table)
    end

    ActiveRecord::Schema.define do
      create_table :accounting_invoices, force: true do |t|
        t.integer :lock_version, default: 0, null: false

        t.timestamps null: false
      end

      create_table :events, force: true do |t|
        t.text :type, null: false
        t.jsonb :payload

        t.datetime :created_at, null: false

        t.references :eventable, polymorphic: true, null: false, index: true
      end

      add_index :events, [:eventable_type, :eventable_id, :created_at],
        name: 'index_events_on_eventable_and_created_at'

      CreateOutboxerMessages.new.change
      CreateOutboxerExceptions.new.change
    end

    class EventHandlerWorker
      def self.perform_async(args)
        # TODO: custom logic here
      end
    end

    module Models
      class Event < ActiveRecord::Base
        include Outboxer::Messageable

        self.inheritance_column = :_type_disabled

        attribute :created_at, :datetime, default: -> { Time.current }

        belongs_to :eventable, polymorphic: true

        validates :type, presence: true
        validates :eventable, presence: true

        has_outboxer_message dependent: :destroy
      end
    end

    module Accounting
      module Invoice
        extend self

        def create!
          ActiveRecord::Base.transaction do
            invoice = Models::Invoice.create!

            event = invoice.events.create!(
              type: 'Accounting::Invoice::Created',
              payload: {
                'invoice' => {
                  'id' => invoice.id } })

            [invoice, event]
          end
        end
      end

      module Models
        class Invoice < ActiveRecord::Base
          self.table_name = 'accounting_invoices'

          has_many :events,
                   -> { order(created_at: :asc) },
                   class_name: 'Models::Event',
                   as: :eventable
        end
      end
    end
  end

  describe ".publish!" do
    context "when unpublished event" do
      it "publishes events" do
        published_events = []

        invoice, created_event = Accounting::Invoice.create!

        expect(Models::Event.count).to eq(1)
        expect(Outboxer::Models::Message.count).to eq(1)

        Outboxer::Message.publish! do |outboxer_messageable|
          case outboxer_messageable.class.name
          when 'Models::Event'
            EventHandlerWorker.perform_async({ 'id' => outboxer_messageable.id })

            published_events << outboxer_messageable
          end
        end

        expect(Models::Event.count).to eq(1)
        expect(Outboxer::Models::Message.count).to eq(0)

        expect(published_events.count).to eq(1)
        published_event = published_events.first

        expect(published_event).to eq(created_event)
        expect(published_event.eventable).to eq(invoice)
        expect(published_event.type).to eq('Accounting::Invoice::Created')
        expect(published_event.payload['invoice']['id']).to eq(invoice.id)
      end
    end

    context "when publishing failed" do
      it "updates outboxer message status to failed" do
        _, event = Accounting::Invoice.create!

        expect(Models::Event.count).to eq(1)
        expect(Outboxer::Models::Message.count).to eq(1)

        begin
          Outboxer::Message.publish! do |_outboxer_messageable|
            raise StandardError, "dummy error"
          end
        rescue => exception
          # no op
        end

        expect(Models::Event.count).to eq(1)
        expect(Outboxer::Models::Message.count).to eq(1)

        outboxer_message = Outboxer::Models::Message.find_by!(outboxer_messageable: event)
        expect(outboxer_message.status).to eq(Outboxer::Models::Message::STATUS[:failed])
        expect(outboxer_message.outboxer_exceptions.count).to eq(1)

        last_outboxer_exception = outboxer_message.outboxer_exceptions.last

        expect(last_outboxer_exception.outboxer_message).to eq(outboxer_message)
        expect(last_outboxer_exception.message_text).to eq("dummy error")
        expect(last_outboxer_exception.class_name).to eq("StandardError")
        expect(last_outboxer_exception.backtrace[1]).to include("lib/outboxer/message.rb")
        expect(last_outboxer_exception.created_at).not_to be_nil
      end

      it "can be republished" do
        Accounting::Invoice.create!

        begin
          Outboxer::Message.publish! do |_event|
            raise StandardError, "dummy error"
          end
        rescue => exception
          # no op
        end

        failed_outboxer_messages = Outboxer::Models::Message
          .where(status: Outboxer::Models::Message::STATUS[:failed])

        expect(failed_outboxer_messages.count).to eq(1)
        failed_outboxer_message = failed_outboxer_messages.first

        Outboxer::Message.republish!(id: failed_outboxer_message.id)

        expect(
          Outboxer::Models::Message
            .where(
              id: failed_outboxer_message.id,
              status: Outboxer::Models::Message::STATUS[:unpublished])
            .count
        ).to eq(1)
      end
    end
  end
end
# rubocop:enable Lint/ConstantDefinitionInBlock
