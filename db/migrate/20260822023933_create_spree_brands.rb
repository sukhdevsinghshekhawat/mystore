class CreateSpreeBrands < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_brands do |t|
      t.string :name, null: false
      t.timestamps
    end
    add_index :spree_brands, :name
  end
end
