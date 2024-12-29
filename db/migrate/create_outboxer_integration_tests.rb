class CreateOutboxerIntegrationTests < ActiveRecord::Migration[7.0]
  def up
    create_table :outboxer_integration_tests do |t|
      t.bigint :tenant_id, null: false

      t.integer :lock_version, default: 0, null: false

      t.timestamps
    end
  end

  def down
    drop_table :outboxer_integration_tests
  end
end
