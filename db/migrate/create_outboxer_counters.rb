class CreateOutboxerCounters < ActiveRecord::Migration[6.1]
  def up
    create_table :outboxer_counters do |t|
      t.string  :name, null: false
      t.bigint  :publisher_id
      t.bigint  :thread_id
      t.bigint  :value, null: false, default: 0
      t.timestamps precision: 6, null: false
    end

    add_index :outboxer_counters, [:name, :publisher_id, :thread_id], unique: true
    add_index :outboxer_counters, [:name, :publisher_id]
    add_index :outboxer_counters, :name
  end

  def down
    drop_table :outboxer_counters if table_exists?(:outboxer_counters)
  end
end
