# frozen_string_literal: true

# Adds foreign key constraint from spree_products.seller_id → spree_vendors.id.
# WHY: The existing seller_id column (host app migration) is an integer
# without a FK constraint. This enforces referential integrity so a product
# cannot reference a non-existent vendor.
class AddForeignKeyToSpreeProductsSellerId < ActiveRecord::Migration[8.0]
  def up
    # Only add FK if the spree_vendors table exists (extension installed)
    if table_exists?(:spree_vendors)
      # Remove existing FK if any (from prior runs)
      if foreign_key_exists?(:spree_products, :spree_vendors, column: :seller_id)
        remove_foreign_key :spree_products, column: :seller_id
      end
      add_foreign_key :spree_products, :spree_vendors, column: :seller_id
    end
  end

  def down
    if foreign_key_exists?(:spree_products, :spree_vendors, column: :seller_id)
      remove_foreign_key :spree_products, column: :seller_id
    end
  end
end
</arg_value>
</write_to_file>