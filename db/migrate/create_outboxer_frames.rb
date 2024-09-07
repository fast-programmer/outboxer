class CreateOutboxerFrames < ActiveRecord::Migration[6.1]
  def up
    create_table :outboxer_frames do |t|
      t.references :exception, foreign_key: { to_table: :outboxer_exceptions },null: false

      t.integer :index, null: false
      t.text :text, null: false

      t.index [:exception_id, :index], unique: true
    end
  end

  def down
    drop_table :outboxer_frames if table_exists?(:outboxer_frames)
  end
end
