class CreateOutboxerPublishers < ActiveRecord::Migration[6.1]
  def up
    ActiveRecord::Base.transaction do
      create_table :outboxer_publishers do |t|
        t.string :identifier, limit: 279, null: false

        t.string :status, limit: 255, null: false

        t.json :info, null: false

        t.timestamps
      end

      add_index :outboxer_publishers, :identifier
    end
  end

  def down
    drop_table :outboxer_publishers
  end
end
