# frozen_string_literal: true

# Spree::VendorBankAccount — Encrypted bank account details for vendors.
#
# WHY NEW MODEL: Bank details must be stored separately from vendors table
# (per approval). Supports multiple accounts per vendor. Sensitive fields
# (account_number, ifsc_code) are encrypted at rest.
#
# REUSE: Inherits from Spree::Base (standard Spree table prefix).
class Spree::VendorBankAccount < Spree::Base
  self.table_name = 'spree_vendor_bank_accounts'

  acts_as_paranoid

  belongs_to :vendor,
             class_name: 'Spree::Vendor',
             foreign_key: 'vendor_id',
             optional: false,
             inverse_of: :bank_accounts

  # Encrypted sensitive fields (Rails 8 built-in encryption)
  encrypts :account_number
  encrypts :ifsc_code

  validates :account_holder_name, :account_number, :bank_name, :ifsc_code, presence: true
  validates :is_default, uniqueness: { scope: :vendor_id }, if: -> { is_default? }
  validate :only_one_default_per_vendor

  scope :defaults, -> { where(is_default: true) }

  # Set this account as default, unset others
  def set_as_default!
    Spree::VendorBankAccount.transaction do
      vendor.bank_accounts.where(is_default: true).update_all(is_default: false)
      update!(is_default: true)
    end
  end

  private

  def only_one_default_per_vendor
    return unless is_default?
    if vendor.bank_accounts.where(is_default: true).where.not(id: id).exists?
      errors.add(:is_default, 'only one default account allowed per vendor')
    end
  end
end
</arg_value>
</write_to_file>