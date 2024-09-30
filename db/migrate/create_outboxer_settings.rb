class CreateOutboxerSettings < ActiveRecord::Migration[6.1]
  def up
    ActiveRecord::Base.transaction do
      create_table :outboxer_settings do |t|
        t.string :name, limit: 255, null: false
        t.string :value, limit: 255, null: false

        t.timestamps
      end

      add_index :outboxer_settings, :name, unique: true
    end
  end

  def down
    drop_table :outboxer_settings
  end
end
