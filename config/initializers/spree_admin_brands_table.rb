Rails.application.config.after_initialize do
  Spree.admin.tables.register(:brands, model_class: Spree::Brand, search_param: :name_cont)

  Spree.admin.tables.brands.add :name,
    label: :name,
    type: :custom,
    partial: 'spree/admin/tables/columns/brand_name',
    sortable: true,
    filterable: true,
    default: true,
    position: 10

  Spree.admin.tables.brands.add :created_at,
    label: :created_at,
    type: :datetime,
    sortable: true,
    filterable: true,
    default: true,
    position: 20

  Spree.admin.tables.brands.add :updated_at,
    label: :updated_at,
    type: :datetime,
    sortable: true,
    filterable: true,
    default: false,
    position: 30
end