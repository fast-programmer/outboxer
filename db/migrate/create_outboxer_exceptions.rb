class CreateOutboxerExceptions < ActiveRecord::Migration[6.1]
  def up
    ActiveRecord::Base.transaction do
      create_table :outboxer_exceptions do |t|
        t.references :message, foreign_key: { to_table: :outboxer_messages }, null: false

        t.string :class_name, limit: 255, null: false
        t.text :message_text, null: false

        t.timestamps
      end

      remove_column :outboxer_exceptions, :updated_at
    end
  end

  def down
    drop_table :outboxer_exceptions if table_exists?(:outboxer_exceptions)
  end
end
