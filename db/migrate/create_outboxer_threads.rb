class CreateOutboxerThreads < ActiveRecord::Migration[6.1]
  def up
    create_table :outboxer_threads do |t|
      t.string  :hostname, limit: 255, null: false
      t.integer :process_id, null: false
      t.integer :thread_id, null: false

      t.integer :queued_message_count, default: 0, null: false
      t.datetime :queued_message_count_last_updated_at, precision: 6, null: true

      t.integer :publishing_message_count, default: 0, null: false
      t.datetime :publishing_message_count_last_updated_at, precision: 6, null: true

      t.integer :published_message_count, default: 0, null: false
      t.datetime :published_message_count_last_updated_at, precision: 6, null: true

      t.integer :failed_message_count, default: 0, null: false
      t.datetime :failed_message_count_last_updated_at, precision: 6, null: true

      t.timestamps null: false
    end

    add_index :outboxer_threads, [:hostname, :process_id, :thread_id],
      unique: true, name: "idx_outboxer_threads"
  end

  def down
    drop_table :outboxer_threads if table_exists?(:outboxer_threads)
  end
end
