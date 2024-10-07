class CreateOutboxerPublishers < ActiveRecord::Migration[6.1]
  def up
    ActiveRecord::Base.transaction do
      create_table :outboxer_publishers do |t|
        t.string :name, limit: 266, null: false
        t.string :status, limit: 255, null: false
        t.string :next_status, limit: 255

        t.json :info, null: false

        t.timestamps
      end

      add_index :outboxer_publishers, :name
    end
  end

  def down
    drop_table :outboxer_processes
  end
end
