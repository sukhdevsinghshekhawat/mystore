# frozen_string_literal: true

# Adds vendor_id to spree_line_items for per-line-item vendor ownership.
# WHY: A single order can contain products from multiple vendors.
# Vendor ownership must be tracked at the line-item level so each vendor
# only sees/manages their own items. Order-level vendor_id is intentionally
# NOT added (multi-vendor orders).
class AddVendorIdToSpreeLineItems < ActiveRecord::Migration[8.0]
  def change
    add_reference :spree_line_items, :vendor,
                  null: true,
                  foreign_key: { to_table: :spree_vendors },
                  index: { name: 'idx_spree_line_items_on_vendor_id' }

    add_index :spree_line_items, [:vendor_id, :order_id],
              name: 'idx_spree_line_items_on_vendor_id_and_order'
  end
end
</arg_value>
</write_to_file>