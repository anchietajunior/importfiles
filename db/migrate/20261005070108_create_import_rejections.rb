class CreateImportRejections < ActiveRecord::Migration[8.1]
  def change
    create_table :import_rejections do |t|
      t.references :import, null: false, foreign_key: true
      t.integer :line_number, null: false
      t.string :npi
      t.string :reason, null: false
    end
  end
end
