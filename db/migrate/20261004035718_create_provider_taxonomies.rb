class CreateProviderTaxonomies < ActiveRecord::Migration[8.1]
  def change
    create_table :provider_taxonomies do |t|
      t.references :provider, null: false, foreign_key: true, index: false
      t.string :code, null: false, index: true

      t.index %i[ provider_id code ], unique: true
    end
  end
end
