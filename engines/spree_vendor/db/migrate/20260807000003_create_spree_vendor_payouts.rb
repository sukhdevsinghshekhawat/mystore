# frozen_string_literal: true

class CreateSpreeVendorPayouts < ActiveRecord::Migration[8.0]
  def change
    create_table :spree_vendor_payouts do |t|
      t.references :vendor, null: false, foreign_key: { to_table: :spree_vendors }, index: { name: 'idx_vendor_payouts_on_vendor' }
      t.references :bank_account, null: true, foreign_key: { to_table: :spree_vendor_bank_accounts }, index: { name: 'idx_vendor_payouts_on_bank_account' }

      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string  :currency, null: false, default: 'USD'
      t.string  :status, null: false, default: 'pending'  # pending/processing/paid/failed
      t.string  :reference
      t.date    :period_start
      t.date    :period_end
      t.datetime :paid_at

      t.timestamps null: false
    end

    add_index :spree_vendor_payouts, [:vendor_id, :status, :period_start, :period_end],
              name: 'idx_vendor_payouts_lookup'
    add_index :spree_vendor_payouts, :status
  end
end
</arg_value>
</write_to_file>