class CreateOutboxerCounters < ActiveRecord::Migration[6.1]
  def up
    create_table :outboxer_counters do |t|
      t.string  :hostname, limit: 255, null: false
      t.integer :process_id, null: false
      t.integer :thread_id, null: false

      t.integer :publisher_id

      t.integer :queued_count,     null: false
      t.integer :publishing_count, null: false
      t.integer :published_count,  null: false
      t.integer :failed_count,     null: false

      t.timestamps
    end

    add_index :outboxer_counters, [:hostname, :process_id, :thread_id],
      unique: true, name: "idx_outboxer_counters_identity"
  end

  def down
    drop_table :outboxer_counters if table_exists?(:outboxer_counters)
  end
end
