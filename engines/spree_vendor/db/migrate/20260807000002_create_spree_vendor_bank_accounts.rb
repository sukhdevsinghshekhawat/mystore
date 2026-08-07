# frozen_string_literal: true

class CreateSpreeVendorBankAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :spree_vendor_bank_accounts do |t|
      t.references :vendor, null: false, foreign_key: { to_table: :spree_vendors }, index: { name: 'idx_vendor_bank_accounts_on_vendor' }

      t.string  :account_holder_name, null: false
      t.string  :account_number, null: false      # encrypted
      t.string  :bank_name, null: false
      t.string  :ifsc_code, null: false           # encrypted
      t.string  :branch
      t.boolean :is_default, default: false, null: false

      t.datetime :deleted_at, index: { name: 'idx_vendor_bank_accounts_on_deleted_at' }
      t.timestamps null: false
    end

    # Only one default account per vendor
    add_index :spree_vendor_bank_accounts, [:vendor_id, :is_default],
              name: 'idx_vendor_bank_accounts_default_unique',
              unique: true,
              where: 'is_default = true AND deleted_at IS NULL'
  end
end