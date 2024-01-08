require_relative "../models"

require_relative "../accounting"

100.times do |_i|
  invoice, created_event = Accounting::Invoice.create!

  puts "Invoice##{invoice.id} - #{created_event.type} event #{created_event.id}"
end
