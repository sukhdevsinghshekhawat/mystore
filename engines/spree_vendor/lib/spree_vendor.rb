# frozen_string_literal: true

require 'spree_vendor/version'
require 'spree_vendor/configuration'
require 'spree_vendor/engine'

module SpreeVendor
  # SpreeVendor configuration accessor
  # Usage: SpreeVendor::Config[:enabled]
  #         SpreeVendor::Config[:vendor_email_from]
  def self.config
    @config ||= Configuration.new
  end
end