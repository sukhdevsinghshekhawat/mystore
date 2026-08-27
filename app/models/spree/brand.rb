module Spree
  class Brand < Spree.base_class
    has_prefix_id :brand

    has_rich_text :description
    has_one_attached :logo

    validates :name, presence: true

    self.whitelisted_ransackable_attributes = %w[name]
    self.whitelisted_ransackable_associations = %w[]
    self.whitelisted_ransackable_scopes = %w[]
  end
end
