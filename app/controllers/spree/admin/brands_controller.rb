module Spree
  module Admin
    class BrandsController < ResourceController
      private

      def permitted_resource_params
        params.require(:brand).permit(
          :name,:description,:logo
        )
      end
    end
  end
end