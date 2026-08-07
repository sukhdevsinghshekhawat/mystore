# frozen_string_literal: true

# Spree::VendorConcern — KEY extension point.
# Spree core conditionally includes this in 7 models:
# Order, Product, Shipment, StockLocation, ShippingMethod, Export, Report
# NEVER modify Spree core — this module is auto-included via the conditional hook.
module Spree::VendorConcern
  extend ActiveSupport::Concern

  module ClassMethods
    def for_vendor(vendor_id)
      where(vendor_id: vendor_id)
    end

    def by_vendor(vendor)
      vid = vendor.is_a?(Spree::Vendor) ? vendor.id : vendor
      where(vendor_id: vid)
    end
  end

  def vendor
    return nil unless vendor_id
    Spree::Vendor.find_by(id: vendor_id)
  end

  def vendor_id
    self[:vendor_id] if self.class.column_names.include?('vendor_id')
  end
end
</arg_value></tool_call>