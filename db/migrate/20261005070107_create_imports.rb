class CreateImports < ActiveRecord::Migration[8.1]
  def change
    create_table :imports do |t|
      t.string :file_name, null: false
      t.string :status, null: false, default: "processing"
      t.integer :rows_read, null: false, default: 0
      t.integer :rows_imported, null: false, default: 0
      t.integer :rows_skipped, null: false, default: 0
      t.integer :rows_rejected, null: false, default: 0
      t.string :failure_reason

      t.timestamps
    end
  end
end
