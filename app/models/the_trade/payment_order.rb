class PaymentOrder < ApplicationRecord
  belongs_to :order, optional: true
  belongs_to :payment, optional: true
  belongs_to :entity, polymorphic: true , optional: true

  validate :for_check_amount

  enum state: [
    :init,
    :confirmed
  ]
  enum before_state: [
      :before_init,
      :before_confirmed
  ]

  def for_check_amount
    if (same_payment_amount + self.check_amount.to_d) >= self.payment.total_amount.floor + 0.99
      self.errors.add(:check_amount, 'The Amount Large than the Total Payment')
    end

    if (same_order_amount + self.check_amount.to_d) >= self.entity.amount.floor + 0.99
      self.errors.add(:check_amount, 'The Amount Large than the Total Order')
    end
  end

  def same_payment_amount
    PaymentOrder.where.not(id: self.id).where(payment_id: self.payment_id).sum(:check_amount)
  end

  def same_order_amount
    received = PaymentOrder.where.not(id: self.id).where(entity_type: self.entity_type, entity_id: self.entity_id).sum(:check_amount)
    received
  end

  def payment_amount
    PaymentOrder.where(payment_id: self.payment_id, state: 'confirmed').sum(:check_amount)
  end

  def order_amount
    PaymentOrder.where(order_id: self.order_id, state: 'confirmed').sum(:check_amount)
  end


  def order_amount_new
    amount = 0
    if self.entity_type == 'Order'
      #得到所有订单明细的id
      order_item_ids = OrderItem.where(order_id: self.entity_id).pluck(:id)
      amount =  PaymentOrder.where("(entity_type = 'Order' and entity_id = ?) or (entity_type = 'OrderItem' and entity_id in ( ? ) ) ", self.entity_id, order_item_ids ).where(state: 'confirmed').sum(:check_amount)  if order_item_ids.present?
      amount =  PaymentOrder.where(entity_type: self.entity_type.to_s, entity_id: self.entity_id, state: 'confirmed').sum(:check_amount)  if order_item_ids.blank?
    else
      _order_id = self.entity.order_id
      order_item_ids = OrderItem.where(order_id: _order_id).pluck(:id)
      amount = PaymentOrder.where("(entity_type = 'Order' and entity_id = ?) or (entity_type = 'OrderItem' and entity_id in ( ? ) ) ", _order_id , order_item_ids ).where(state: 'confirmed').sum(:check_amount)  if order_item_ids.present?
      amount = PaymentOrder.where(entity_type: 'Order', entity_id: _order_id, state: 'confirmed').sum(:check_amount)  if order_item_ids.blank?
    end
    return amount
  end


  def order_item_amount
      PaymentOrder.where(entity_type: self.entity_type , entity_id: self.entity_id, state: 'confirmed').sum(:check_amount)
  end

  def confirm!
    self.state = 'confirmed'
    begin
      self.save!
      self.class.transaction do
        update_order_state
        update_payment_state
      end
    rescue => e
      raise e
    end
  end


  def revert_confirm!
    self.state = 'init'
    self.save!

    self.class.transaction do
      update_order_state
      update_payment_state
    end
    self.delete
  end

  def update_order_state
     if self.entity_type.to_s == 'Order'
       entity.received_amount = order_amount_new
       entity.received_pure_serve_sum = order_pure_serve_sum  if order_pure_serve_sum.present?
       entity.check_state!
     else
       entity.order&.received_amount = order_amount_new
       entity.order&.check_state!

       entity.received_amount = order_item_amount
       entity.check_state_detail!
     end
  end

  def update_payment_state
    payment.checked_amount = payment_amount
    payment.check_state!
  end


  def order_pure_serve_sum
    if self.entity_type == 'Order'
      #得到所有订单明细的id
      PaymentOrder.where(entity_type: self.entity_type.to_s, entity_id: self.entity_id, state: 'confirmed', order_id: nil).sum(:check_amount)
    end
  end

end