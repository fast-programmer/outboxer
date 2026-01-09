class CreateOutboxerEvents < ActiveRecord::Migration[7.0]
  def up
    create_table :outboxer_events do |t|
      t.integer :order, null: false
      t.datetime :created_at, null: false

      t.string :eventable_id, limit: 255, null: false
      t.string :eventable_type, limit: 255, null: false

      t.string :type, null: false, limit: 255
      t.send json_column_type, :body

      t.index :created_at
      t.index [:type, :created_at]
    end
  end

  def down
    drop_table :outboxer_events if table_exists?(:outboxer_events)
  end

  private

  def json_column_type
    case ActiveRecord::Base.connection.adapter_name
    when /PostgreSQL/
      :jsonb
    else
      :json
    end
  end
end
