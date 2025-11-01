class CreateOutboxerMessageCounts < ActiveRecord::Migration[6.1]
  def up
    create_table :outboxer_message_counts do |t|
      t.string  :hostname, limit: 255, null: false
      t.integer :process_id, null: false
      t.integer :thread_id, null: false

      t.integer :queued,     null: false
      t.integer :publishing, null: false
      t.integer :published,  null: false
      t.integer :failed,     null: false

      t.timestamps null: false
    end

    add_index :outboxer_message_counts, [:hostname, :process_id, :thread_id],
      unique: true, name: "idx_outboxer_message_counts_identity"
  end

  def down
    drop_table :outboxer_message_counts if table_exists?(:outboxer_message_counts)
  end
end
