# frozen_string_literal: true

lib = File.expand_path('lib/', __dir__)
$LOAD_PATH.unshift lib unless $LOAD_PATH.include?(lib)

require 'spree_vendor/version'

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_vendor'
  s.version     = SpreeVendor::VERSION
  s.summary     = 'Spree Commerce Vendor (Supplier) Management Extension'
  s.description = 'Production-grade Vendor Management System for Spree Commerce. Includes vendor profiles, bank accounts, order assignment/acceptance/rejection, packing, shipping/tracking, payouts, and notifications.'
  s.required_ruby_version = '>= 3.2'

  s.author      = 'Rajvastra'
  s.email       = 'dev@rajvastra.com'
  s.homepage    = 'https://github.com/rajvastra/spree_vendor'
  s.license     = 'MIT'

  s.files       = Dir["{app,config,db,lib}/**/*", "LICENSE.md", "Rakefile", "README.md"].reject { |f| f.match(/^spec/) && !f.match(/^spec\/fixtures/) }
  s.require_path = 'lib'

  s.metadata['allowed_push_host'] = 'https://rubygems.org'

  spree_version = '>= 5.4.0.beta'
  s.add_dependency 'spree', spree_version
  s.add_dependency 'spree_admin', spree_version
  s.add_dependency 'spree_api', spree_version
  s.add_dependency 'spree_emails', spree_version

  # Notification channels (abstract providers)
  s.add_dependency 'noticed', '~> 2.0'
  s.add_dependency 'phonelib', '~> 0.8'

  # Email provider (default: Resend)
  s.add_dependency 'resend', '~> 0.16'

  # HTTP client for WhatsApp Meta Cloud API
  s.add_dependency 'faraday', '~> 2.0'

  s.add_development_dependency 'spree_dev_tools'
end