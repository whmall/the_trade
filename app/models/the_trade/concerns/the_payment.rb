# payment_id
# payment_type
# amount
# received_amount
module ThePayment

  def unreceived_amount
    self.amount.to_d - self.received_amount.to_d
  end

  # 未收款服务费
  def unreceived_pure_serve_sum
    self.pure_serve_sum.to_d - self.received_pure_serve_sum.to_d
  end


  def init_received_amount
    self.payment_orders.sum(:check_amount)
  end


  def init_serve_received_amount
    self.payment_orders.where(order_id: nil).sum(:check_amount)
  end


  def pending_payments
    Payment.where.not(id: self.payment_orders.pluck(:payment_id)).where(payment_method_id: self.buyer.payment_method_ids, state: ['init', 'part_checked'])
  end

  def exists_payments
    Payment.where.not(id: self.payment_orders.pluck(:payment_id)).exists?(payment_method_id: self.buyer.payment_method_ids, state: ['init', 'part_checked'])
  end


  def order_item_exists_payments
    Payment.where.not(id: self.payment_orders.pluck(:payment_id)).exists?(payment_method_id: self.order&.buyer.payment_method_ids, state: ['init', 'part_checked'])
  end

  def order_item_pending_payments
    Payment.where.not(id: self.payment_orders.pluck(:payment_id)).where(payment_method_id: self.order.buyer.payment_method_ids, state: ['init', 'part_checked'])
  end






  def confirm_paid!
    binding.pry
    self.order_items.each do |oi|
      oi.confirm_paid!
    end
  end

  def confirm_part_paid!
    self.order_items.each do |oi|
      oi.confirm_part_paid!
    end
  end

  def change_to_paid!(params = {})
    if self.amount == 0
      self.received_amount = self.amount
      self.check_state!
      return self
    end

    if self.payment_status == 'all_paid'
      return self
    end

    if params[:type]
      self.save_detail(params)
    elsif self.payment_type.present?
      begin
        self.send self.payment_type + '_result'
      rescue NoMethodError
        self
      end
    end
  end

  def save_detail(params)
    payment = self.payments.build(type: params[:type])
    payment.assign_detail params
    payment_order = payment.payment_orders.build(order_id: self.id, check_amount: payment.total_amount)
    Payment.transaction do
      payment.save!
      payment_order.confirm!
    end
  end

  def check_state
    if self.received_amount.to_d >= self.amount
      self.payment_status = 'all_paid'
      self.confirm_paid!
    elsif self.received_amount.to_d > 0 && self.received_amount.to_d < self.amount
      self.payment_status = 'part_paid'
      self.confirm_part_paid!
    elsif self.received_amount.to_d <= 0
      self.payment_status = 'unpaid'
    end
  end

  def check_state!
    self.check_state
    self.save!
  end


  def check_state_detail
    if self.received_amount.to_d >= self.amount
      self.payment_status = 'all_paid'
    elsif self.received_amount.to_d > 0 && self.received_amount.to_d < self.amount
      self.payment_status = 'part_paid'
    elsif self.received_amount.to_d <= 0
      self.payment_status = 'unpaid'
    end
  end

  def check_state_detail!
    self.check_state_detail
    self.save!
  end

end