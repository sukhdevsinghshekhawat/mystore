class Spree::User < Spree.base_class
    # Spree modules
    include Spree::UserAddress
    include Spree::UserMethods
    include Spree::UserPaymentSource
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  #   - `:confirmable` = Email confirmation (email verify karna)
  # - `:lockable` = Failed attempts par account lock
  # - `:timeoutable` = Session timeout
  # - `:trackable` = Login tracking (IP, time, etc.)
  # - `:omniauthable` = Social login (Google, Facebook)

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
end
