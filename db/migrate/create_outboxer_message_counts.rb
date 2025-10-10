class CreateOutboxerMessageCounts < ActiveRecord::Migration[7.1]
  def up
    create_table :outboxer_message_counts do |t|
      t.string  :status,    limit: 32, null: false
      t.integer :partition, null: false
      t.bigint  :value,     null: false, default: 0
      t.timestamps
    end

    add_index :outboxer_message_counts, [:status, :partition],
      unique: true, name: :idx_outboxer_counts_status_partition
  end

  def down
    drop_table :outboxer_message_counts if table_exists?(:outboxer_message_counts)
  end
end
