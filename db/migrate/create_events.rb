class CreateEvents < ActiveRecord::Migration[7.0]
  def up
    create_table :events do |t|
      t.bigint :user_id
      t.bigint :tenant_id

      t.string :eventable_type, limit: 255
      t.bigint :eventable_id
      t.index [:eventable_type, :eventable_id]

      t.string :type, null: false, limit: 255
      t.send(json_column_type, :body)
      t.datetime :created_at, null: false
    end
  end

  def down
    drop_table :events if table_exists?(:events)
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
