class CreateEvents < ActiveRecord::Migration[6.1]
  def up
    create_table :events do |t|
      # t.bigint :user_id, null: false
      # t.bigint :tenant_id, null: false

      # t.text :type, null: false

      # t.text :eventable_type, null: false
      # t.bigint :eventable_id, null: false

      # t.json :headers

      # t.json :body

      # t.datetime :created_at, null: false
    end

    # add_index :events, [:eventable_type, :eventable_id]
  end

  def down
    drop_table :events if table_exists?(:events)
  end
end
