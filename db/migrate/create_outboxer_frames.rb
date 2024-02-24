class CreateOutboxerFrames < ActiveRecord::Migration[6.1]
  def up
    create_table :outboxer_frames, id: false do |t|
        t.uuid :id, primary_key: true

      t.references :exception,
        null: false, type: :uuid, foreign_key: { to_table: :outboxer_exceptions }

      t.integer :index, null: false
      t.text :text, null: false

      t.index [:exception_id, :index], unique: true
    end
  end

  def down
    drop_table :outboxer_frames if table_exists?(:outboxer_frames)
  end
end
