# frozen_string_literal: true

# Spree::Vendor — Vendor (Supplier) profile entity.
#
# WHY NEW MODEL: Spree has no business-entity model. Spree::User is customer
# authentication; Spree::AdminUser is admin authentication. Neither models
# a business with GST/PAN/bank details/verification status.
#
# REUSE: Uses Spree::Address for address, ActiveStorage for profile image,
#        Spree::StockLocation for inventory (via VendorConcern),
#        Spree::Product (seller_id) for products.
#
# NEVER DUPLICATES: Does not replace Spree::User, Spree::AdminUser, or
#                   Spree::StockLocation.
class Spree::Vendor < Spree::Base
  self.table_name = 'spree_vendors'

  # --- Soft delete ---
  acts_as_paranoid

  # --- Profile image (ActiveStorage) ---
  has_one_attached :profile_image

  # --- Address (reuse Spree::Address) ---
  belongs_to :address, class_name: 'Spree::Address', optional: true

  # --- Bank accounts (separate table, multiple) ---
  has_many :bank_accounts,
           class_name: 'Spree::VendorBankAccount',
           foreign_key: 'vendor_id',
           dependent: :restrict_with_error,
           inverse_of: :vendor

  # --- Payouts ---
  has_many :payouts,
           class_name: 'Spree::VendorPayout',
           foreign_key: 'vendor_id',
           dependent: :restrict_with_error

  # --- Products (reuse seller_id) ---
  has_many :products,
           class_name: 'Spree::Product',
           foreign_key: 'seller_id',
           inverse_of: :vendor,
           dependent: :restrict_with_error

  # --- Line items (per-line-item vendor ownership) ---
  has_many :line_items,
           class_name: 'Spree::LineItem',
           foreign_key: 'vendor_id',
           dependent: :restrict_with_error

  # --- Shipments (per-shipment vendor ownership) ---
  has_many :shipments,
           class_name: 'Spree::Shipment',
           foreign_key: 'vendor_id',
           dependent: :restrict_with_error

  # --- Stock location (Vendor → StockLocation → Inventory) ---
  has_one :stock_location,
          class_name: 'Spree::StockLocation',
          foreign_key: 'vendor_id',
          dependent: :restrict_with_error

  # --- Audit ---
  belongs_to :created_by, class_name: 'Spree::AdminUser', optional: true
  belongs_to :updated_by, class_name: 'Spree::AdminUser', optional: true

  # --- Status enums ---
  enum :status, { pending: 'pending', active: 'active', suspended: 'suspended' }
  enum :verification_status,
       { unverified: 'unverified', pending: 'pending', verified: 'verified', rejected: 'rejected' }

  # --- Validations ---
  validates :name, :business_name, :owner_name, :email, presence: true
  validates :email, uniqueness: { scope: :deleted_at, case_sensitive: false }
  validates :phone, presence: true, if: -> { SpreeVendor::Config[:require_phone] }
  validates :gst_number, uniqueness: { scope: :deleted_at }, allow_blank: true
  validates :pan_number, uniqueness: { scope: :deleted_at }, allow_blank: true
  validate :cannot_suspend_if_active_shipments

  # --- Scopes ---
  scope :verified, -> { where(verification_status: 'verified') }
  scope :active_vendors, -> { where(status: 'active') }
  scope :with_pending_orders, -> do
    joins(:line_items)
      .where(spree_line_items: { vendor_id: nil })
      .distinct
  end

  # --- Callbacks ---
  before_validation :set_defaults, on: :create
  after_update :recalculate_revenue_cache, if: -> { saved_change_to_status? || saved_change_to_verification_status? }

  # --- Public API ---

  # Total revenue (cached, async updated)
  def total_revenue
    cached_revenue['total'] || 0
  end

  # Revenue for a given period (cached)
  def revenue_for_period(start_date, end_date)
    key = "period_#{start_date}_#{end_date}"
    cached_revenue[key] || 0
  end

  # Force async revenue recalculation
  def recalculate_revenue!
    SpreeVendor::RevenueRecalculationJob.perform_later(id)
  end

  # Default bank account
  def default_bank_account
    bank_accounts.find_by(is_default: true) || bank_accounts.first
  end

  # Vendor's admin users (via Spree::RoleUser)
  def users
    Spree::AdminUser.joins(:roles)
                    .where(spree_roles: { name: 'vendor' })
                    .joins("INNER JOIN spree_role_users ON spree_role_users.user_id = spree_admin_users.id")
                    .where(spree_role_users: { vendor_id: id })
  end

  # Is this vendor active and verified?
  def can_fulfill?
    active? && verified?
  end

  private

  def set_defaults
    self.status ||= 'pending'
    self.verification_status ||= 'unverified'
  end

  def cannot_suspend_if_active_shipments
    if status == 'suspended' && shipments.where(state: %w[ready shipped]).exists?
      errors.add(:status, 'cannot be suspended while shipments are in ready or shipped state')
    end
  end

  def recalculate_revenue_cache
    recalculate_revenue!
  end
end
</arg_value>
</write_to_file>