class CreateProviders < ActiveRecord::Migration[8.1]
  def change
    create_table :providers do |t|
      t.string :npi, null: false, index: { unique: true }
      t.integer :entity_type
      t.string :name
      t.string :state, index: true
      t.date :deactivated_on
      t.date :reactivated_on
      t.date :last_updated_on

      t.timestamps
    end
  end
end
