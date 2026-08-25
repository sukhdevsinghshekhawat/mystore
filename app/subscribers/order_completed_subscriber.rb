# # app/subscribers/order_completed_subscriber.rb
# class OrderCompletedSubscriber < Spree::Subscriber
#   subscribes_to 'order.completed'
#   def handle(event)
#     order = Spree::Order.find_by_prefix_id(event.payload['id'])
#     ExternalService.notify_order_placed(order)
#   end
# end