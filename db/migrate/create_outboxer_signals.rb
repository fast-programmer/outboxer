class CreateOutboxerSignals < ActiveRecord::Migration[6.1]
  def up
    ActiveRecord::Base.transaction do
      create_table :outboxer_signals do |t|
        t.string :name, limit: 9, null: false
        t.references :publisher, foreign_key: { to_table: :outboxer_publishers }, null: false

        t.timestamps
      end
    end
  end

  def down
    drop_table :outboxer_signals
  end
end
