class CreateOutboxerMetrics < ActiveRecord::Migration[6.1]
  def up
    ActiveRecord::Base.transaction do
      create_table :outboxer_metrics do |t|
        t.string :name, limit: 255, null: false
        t.decimal :value, precision: 20, scale: 4, default: 0, null: false

        t.timestamps
      end

      add_index :outboxer_metrics, :name, unique: true
    end
  end

  def down
    drop_table :outboxer_metrics
  end
end
