class VendorAbility < Spree::PermissionSets::Base
  def activate!
    # admin panel mein Products section access karne ki permission
    can [:admin, :create], Spree::Product

    # sirf apne banaye products ko dekhna/edit/delete karne ki permission
    can [:admin, :index,:read, :update, :destroy], Spree::Product, seller_id: user.id
  end
end 



