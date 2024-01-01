class CreateAccountingInvoices < ActiveRecord::Migration[6.1]
  def change
    create_table :accounting_invoices, force: true do |t|
      t.integer :lock_version, default: 0, null: false

      t.timestamps null: false
    end
  end
end

