module Models
  class Invoice < ActiveRecord::Base
    self.table_name = 'accounting_invoices'

    has_many :events,
              -> { order(created_at: :asc) },
              class_name: 'Models::Event',
              as: :eventable
  end
end
