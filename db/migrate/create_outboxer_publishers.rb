class CreateOutboxerPublishers < ActiveRecord::Migration[6.1]
  def up
    ActiveRecord::Base.transaction do
      create_table :outboxer_publishers do |t|
        t.string :key, limit: 279, null: false
        # 255 (hostname) + 1 (colon) + 10 (PID) + 1 (colon) + 12 (unique ID) = 279 characters

        t.string :status, limit: 255, null: false

        t.json :info, null: false

        t.timestamps
      end

      add_index :outboxer_publishers, :key, unique: true
    end
  end

  def down
    drop_table :outboxer_publishers
  end
end
