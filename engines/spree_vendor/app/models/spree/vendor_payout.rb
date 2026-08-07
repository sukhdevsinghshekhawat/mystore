# frozen_string_literal: true

# Spree::VendorPayout — Payout records for vendor revenue.
# WHY: Spree has no payout model. StoreCredits are customer credits, not vendor payouts.
class Spree::VendorPayout < Spree::Base
  self.table_name = 'spree_vendor_payouts'
  acts_as_paranoid

  belongs_to :vendor, class_name: 'Spree::Vendor', foreign_key: 'vendor_id', optional: false
  belongs_to :bank_account, class_name: 'Spree::VendorBankAccount', foreign_key: 'bank_account_id', optional: true

  enum :status, { pending: 'pending', processing: 'processing', paid: 'paid', failed: 'failed' }

  validates :amount, :currency, presence: true
  validates :amount, numericality: { greater_than: 0 }

  scope :paid, -> { where(status: 'paid') }
  scope :pending_payouts, -> { where(status: 'pending') }
  scope :for_period, ->(start_date, end_date) {
    where('period_start >= ? AND period_end <= ?', start_date, end_date)
  }

  def mark_as_paid!
    update!(status: 'paid', paid_at: Time.current)
  end

  def mark_as_failed!
    update!(status: 'failed')
  end
end
</arg_value>
</write_to_file>