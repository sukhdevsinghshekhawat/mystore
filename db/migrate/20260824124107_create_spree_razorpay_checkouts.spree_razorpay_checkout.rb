# This migration comes from spree_razorpay_checkout (originally 20220816080140)
class CreateSpreeRazorpayCheckouts < ActiveRecord::Migration[6.1]
  def change
    create_table :spree_razorpay_checkouts do |t|
      t.references :order, null: true, foreign_key: { to_table: :spree_orders }
      t.string :razorpay_order_id
      t.string :razorpay_payment_id
      t.string :razorpay_signature
      t.string :status
      t.string :payment_method
      t.string :card_id
      t.string :bank
      t.string :wallet
      t.string :vpa
      t.string :email
      t.string :contact

      t.timestamps
    end

    add_index :spree_razorpay_checkouts, :razorpay_order_id
    add_index :spree_razorpay_checkouts, :razorpay_payment_id
  end
end
