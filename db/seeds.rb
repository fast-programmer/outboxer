require_relative '../app/models/invoice'
require_relative '../app/models/event'

500.times do |_i|
  invoice = Invoice.create!
  event = invoice.events.create!(type: 'Invoice.created')

  puts "Invoice##{invoice.id} - #{event.type} event #{event.id}"
end
