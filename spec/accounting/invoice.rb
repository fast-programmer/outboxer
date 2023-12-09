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
end
