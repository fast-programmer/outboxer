class CreateEvents < ActiveRecord::Migration[7.0]
  def up
    create_table :events do |t|
      t.bigint :user_id, null: false
      t.bigint :tenant_id, null: false

      t.string :type, null: false, limit: 255
      t.send(json_column_type, :body)
      t.datetime :created_at, null: false

      t.string :eventable_type, null: false, limit: 255
      t.bigint :eventable_id, null: false
      t.index [:eventable_type, :eventable_id]
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
    when /MySQL/, /MariaDB/
      :json
    when /SQLite/
      :text
    else
      :json
    end
  end
end
