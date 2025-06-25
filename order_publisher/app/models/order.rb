class Order < ApplicationRecord
  after_create :publish_order_created
  after_update :publish_order_updated, if: :saved_change_to_status?

  private

  def publish_order_created
    OrderEventPublisher.publish('order.created', self)
  end

  def publish_order_updated
    OrderEventPublisher.publish('order.updated', self)
  end
end