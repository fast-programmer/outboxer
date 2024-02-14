class CreateOutboxerFrames < ActiveRecord::Migration[6.1]
  def up
    create_table :outboxer_frames do |t|
      t.references :exception, null: false, foreign_key: { to_table: :outboxer_exceptions }

      t.integer :index, null: false
      t.text :text, null: false

      # TODO: add uniqueness column
    end
  end

  def down
    drop_table :outboxer_frames if table_exists?(:outboxer_frames)
  end
end
