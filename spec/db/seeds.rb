#!/usr/bin/env ruby

require 'bundler/setup'
Bundler.require(:default, ENV.fetch['RAILS_ENV'])

require_relative "../models/event"
require_relative "../accounting/models/invoice"
require_relative "../accounting/invoice"

# require_relative "../generators/outboxer/templates/workers/event_handler_worker"

10.times do |_i|
  invoice, created_event = Accounting::Invoice.create!

  puts "Invoice##{invoice.id} - #{created_event.type} event #{event.id}"
end
