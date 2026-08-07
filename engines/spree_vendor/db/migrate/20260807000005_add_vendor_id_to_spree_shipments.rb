# frozen_string_literal: true

# Adds vendor_id to spree_shipments for per-shipment vendor ownership.
# WHY: Shipments are created per stock location. Each vendor has their own
# stock location, so each shipment belongs to one vendor. This enables
# vendor-scoped shipment queries and tracking.
class AddVendorIdToSpreeShipments < ActiveRecord::Migration[8.0]
  def change
    add_reference :spree_shipments, :vendor,
                  null: true,
                  foreign_key: { to_table: :spree_vendors },
                  index: { name: 'idx_spree_shipments_on_vendor_id' }
  end
end
</arg_value>
</write_to_file>