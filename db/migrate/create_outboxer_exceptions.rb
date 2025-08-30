class CreateOutboxerExceptions < ActiveRecord::Migration[6.1]
  def up
    ActiveRecord::Base.transaction do
      create_table :outboxer_exceptions do |t|
        t.string :class_name, limit: 255
        t.text :message_text, null: false

        t.datetime :created_at, null: false

        t.references :message,
          foreign_key: { to_table: :outboxer_messages, on_delete: :cascade },
          null: false
      end
    end
  end

  def down
    drop_table :outboxer_exceptions if table_exists?(:outboxer_exceptions)
  end
end
