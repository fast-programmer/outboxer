class CreateOutboxerLocks < ActiveRecord::Migration[6.1]
  def up
    create_table :outboxer_locks do |t|
      t.string :key, null: false, limit: 255
      t.index [:key], unique: true

      t.timestamps

    end

    Outboxer::Models::Lock.create!(key: 'messages/report_statsd_guages')
  end

  def down
    drop_table :outboxer_locks if table_exists?(:outboxer_locks)
  end
end
