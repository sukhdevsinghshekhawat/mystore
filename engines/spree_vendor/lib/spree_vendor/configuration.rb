# frozen_string_literal: true

module SpreeVendor
  class Configuration < Spree::Preferences::Configuration
    # Whether the vendor module is active
    preference :enabled, :boolean, default: true

    # Default from-email for vendor mailers
    preference :vendor_email_from, :string, default: 'noreply@example.com'

    # Whether to send vendor order emails
    preference :send_vendor_order_emails, :boolean, default: true

    # Whether to send WhatsApp notifications (requires provider credentials)
    preference :send_whatsapp_notifications, :boolean, default: false

    # Default WhatsApp sender phone number ID (Meta Cloud API)
    preference :whatsapp_phone_number_id, :string, default: ''

    # WhatsApp API token (Meta Cloud API)
    preference :whatsapp_access_token, :string, default: ''

    # Email provider: :resend (default), future: :ses, :mailgun, :sendgrid
    preference :email_provider, :string, default: 'resend'

    # WhatsApp provider: :meta (default), future: :twilio, :interakt, :gupshup
    preference :whatsapp_provider, :string, default: 'meta'

    # API base for Meta WhatsApp Cloud API
    preference :whatsapp_api_base, :string, default: 'https://graph.facebook.com/v19.0'

    # Revenue cache TTL in seconds (default: 1 hour)
    preference :revenue_cache_ttl, :integer, default: 3600

    # Whether vendors can self-register (default: admin creates vendors)
    preference :allow_vendor_self_registration, :boolean, default: false
  end
end