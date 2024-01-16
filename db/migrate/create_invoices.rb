class CreateInvoices < ActiveRecord::Migration[6.1]
  def up
    create_table :invoices, force: true do |t|
      t.integer :lock_version, default: 0, null: false

      t.timestamps null: false
    end
  end

  def down
    drop_table :invoices
  end
end

