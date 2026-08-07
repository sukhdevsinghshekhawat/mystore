class AddSellerIdToSpreeProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :spree_products, :seller_id, :integer
    add_index :spree_products, :seller_id
  end
end