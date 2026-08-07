# frozen_string_literal: true

module SpreeVendor
  class Engine < Rails::Engine
    require 'spree/core'
    require 'spree/admin'
    require 'spree/api'
    require 'spree/emails'
    require 'noticed'
    require 'phonelib'
    require 'resend'
    require 'faraday'

    isolate_namespace Spree
    engine_name 'spree_vendor'

    config.generators do |g|
      g.test_framework :rspec
    end

    initializer 'spree_vendor.environment', before: :load_config_initializers do |_app|
      SpreeVendor::Config = SpreeVendor::Configuration.new
    end

    initializer 'spree_vendor.assets' do |app|
      if app.config.respond_to?(:assets)
        app.config.assets.precompile += %w[spree_vendor_manifest]
      end
    end

    initializer 'spree_vendor.importmap', before: 'importmap' do |app|
      if app.config.respond_to?(:importmap)
        app.config.importmap.paths << root.join('config/importmap.rb')
        app.config.importmap.cache_sweepers << root.join('app/javascript')
      end
    end

    initializer 'spree_vendor.subscribers' do
      Spree.subscribers << SpreeVendor::Subscribers::OrderAssignmentSubscriber
      Spree.subscribers << SpreeVendor::Subscribers::OrderStatusSubscriber
    end
  end
end