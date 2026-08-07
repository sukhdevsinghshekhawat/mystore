# frozen_string_literal: true

class CreateSpreeVendors < ActiveRecord::Migration[8.0]
  def change
    create_table :spree_vendors do |t|
      # Core vendor identity
      t.string  :name, null: false
      t.string  :business_name, null: false
      t.string  :owner_name, null: false
      t.string  :gst_number
      t.string  :pan_number
      t.string  :phone
      t.string  :email, null: false

      # Status: pending / active / suspended
      t.string  :status, null: false, default: 'pending'

      # Verification: unverified / pending / verified / rejected
      t.string  :verification_status, null: false, default: 'unverified'

      # Addresses belong to Spree::Address
      t.references :address, null: true, index: { name: 'idx_spree_vendors_on_address' }
      t.references :primary_address, null: true, index: { name: 'idx_spree_vendors_on_primary_address' }

      # Profile image via ActiveStorage
      t.references :profile_image, null: true, index: { name: 'idx_spree_vendors_on_profile_image' }

      # Audit fields (admin who created/updated)
      t.references :created_by, null: true, polymorphic: true, index: { name: 'idx_spree_vendors_on_created_by' }
      t.references :updated_by, null: true, polymorphic: true, index: { name: 'idx_spree_vendors_on_updated_by' }

      # Revenue cache (async updated)
      t.jsonb :cached_revenue, null: false, default: {}
      t.datetime :revenue_cached_at

      # Deleted at for soft delete (acts_as_paranoid pattern)
      t.datetime :deleted_at, null: true, index: { name: 'idx_spree_vendors_on_deleted_at' }

      t.timestamps null: false
    end

    add_index :spree_vendors, :status
    add_index :spree_vendors, :verification_status
    add_index :spree_vendors, :email, unique: true, where: 'deleted_at IS NULL'
    add_index :spree_vendors, :phone
    add_index :spree_vendors, :business_name
  end
end