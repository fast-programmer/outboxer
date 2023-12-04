class CreateOutboxerExceptions < ActiveRecord::Migration[6.1]
  def change
    create_table :outboxer_exceptions do |t|
      t.references :outboxer_message, null: false, foreign_key: { to_table: :outboxer_messages }

      t.text :class_name, null: false
      t.text :message_text, null: false
      t.column :backtrace, :text, array: true

      t.timestamps
    end

    remove_column :outboxer_exceptions, :updated_at
  end
end
