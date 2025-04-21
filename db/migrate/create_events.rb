class CreateEvents < ActiveRecord::Migration[7.0]
  def up
    create_table :events do |t|
      t.string :type, null: false, limit: 255
      t.send json_column_type, :body

      t.datetime :created_at, null: false

      t.index :created_at
      t.index [:type, :created_at]
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
