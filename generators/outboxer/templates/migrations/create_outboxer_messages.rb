class CreateOutboxerMessages < ActiveRecord::Migration[6.1]
  def change
    create_table :outboxer_messages do |t|
      t.text :status, null: false

      t.references :outboxer_messageable, polymorphic: true, null: false

      t.timestamps
    end

    add_index :outboxer_messages, %i[status created_at]
  end
end
