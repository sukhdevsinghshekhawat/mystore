module Spree
  module Admin
    module ProductsControllerDecorator
      def build_resource
        resource = super
        resource.seller_id = current_admin_user.id if current_admin_user
        resource
      end
    end
  end
end

Spree::Admin::ProductsController.prepend(Spree::Admin::ProductsControllerDecorator)