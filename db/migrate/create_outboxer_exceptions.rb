class CreateOutboxerExceptions < ActiveRecord::Migration[6.1]
  def up
    create_table :outboxer_exceptions do |t|
      t.references :message, null: false, foreign_key: { to_table: :outboxer_messages }

      t.text :class_name, null: false
      t.text :message_text, null: false

      t.timestamps
    end

    remove_column :outboxer_exceptions, :updated_at
  end

  def down
    drop_table :outboxer_exceptions if table_exists?(:outboxer_exceptions)
  end
end
