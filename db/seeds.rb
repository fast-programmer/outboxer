require_relative '../app/models/invoice'
require_relative '../app/models/event'

loop do
  10.times do |_i|
    invoice = Invoice.create!
    event = invoice.events.create!(type: 'Invoice.created')

    puts "Invoice##{invoice.id} - #{event.type} event #{event.id}"
  end

  sleep 1
end
