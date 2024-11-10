class CreateOutboxerPublishers < ActiveRecord::Migration[6.1]
  def up
    ActiveRecord::Base.transaction do
      create_table :outboxer_publishers do |t|
        t.string :name, limit: 263, null: false # 255 (hostname) + 1 (colon) + 7 (pid)
        t.string :status, limit: 255, null: false
        t.json :settings, null: false
        t.json :metrics, null: false

        t.timestamps
      end
    end
  end

  def down
    drop_table :outboxer_publishers
  end
end
