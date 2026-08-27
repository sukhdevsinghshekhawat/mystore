Rails.application.config.after_initialize do
  Spree.admin.navigation.sidebar.add :brands,
    label: :brands,
    url: :admin_brands_path,
    icon: 'award',
    position: 35,
    active: -> { controller_name == 'brands' },
    if: -> { can?(:manage, Spree::Brand) }
end
