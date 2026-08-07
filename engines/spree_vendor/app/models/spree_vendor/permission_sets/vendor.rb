# frozen_string_literal: true
module SpreeVendor
  module PermissionSets
    class Vendor < Spree::PermissionSets::Base
      def activate!
        can [:admin, :index, :read, :update, :destroy], Spree::Product, seller_id: user.id
        can :create, Spree::Product
        can :read, Spree::Order, line_items: { vendor_id: user.vendor_id }
        can [:read, :update], Spree::Shipment, vendor_id: user.vendor_id
        can [:read, :update], Spree::StockItem, stock_location: { vendor_id: user.vendor_id }
        can [:read, :create, :update, :destroy], Spree::VendorBankAccount, vendor_id: user.vendor_id
        can :read, Spree::VendorPayout, vendor_id: user.vendor_id
        can :read, Spree::Vendor, id: user.vendor_id
      end
    end
  end
end
</arg_value></tool_call>