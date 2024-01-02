class CreateOutboxerExceptions < ActiveRecord::Migration[6.1]
  def up
    create_table :outboxer_exceptions do |t|
      t.references :outboxer_message, null: false, foreign_key: { to_table: :outboxer_messages }

      t.string :class_name, null: false
      t.string :message_text, null: false
      t.column :backtrace, :text, array: true

      t.timestamps
    end

    remove_column :outboxer_exceptions, :updated_at
  end

  def down
    drop_table :outboxer_exceptions if table_exists?(:outboxer_exceptions)
  end
end
