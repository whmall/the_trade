class Order < ApplicationRecord
  include ThePayment
  include TheRefund

  belongs_to :payment_strategy, optional: true
  belongs_to :user, optional: true
  belongs_to :buyer, class_name: '::Buyer', foreign_key: :buyer_id
  has_many :payment_orders, inverse_of: :order, dependent: :destroy
  has_many :payments, through: :payment_orders
  has_many :order_items, dependent: :destroy, autosave: true, inverse_of: :order
  has_many :refunds, dependent: :nullify, inverse_of: :order
  has_many :order_promotes, autosave: true, inverse_of: :order
  has_many :order_serves, autosave: true
  has_many :pure_order_promotes, -> { where(order_item_id: nil) }, class_name: 'OrderPromote'
  has_many :pure_order_serves, -> { where(order_item_id: nil) }, class_name: 'OrderServe'

  accepts_nested_attributes_for :order_items
  accepts_nested_attributes_for :order_serves
  accepts_nested_attributes_for :order_promotes

  scope :credited, -> { where(payment_strategy_id: PaymentStrategy.where.not(period: 0).pluck(:id)) }
  scope :to_pay, -> { where(payment_status: ['unpaid', 'part_paid']) }

  after_initialize if: :new_record? do |o|
    self.uuid = UidHelper.nsec_uuid('OD')
    self.payment_status = 'unpaid'
    self.buyer_id = self.user&.buyer_id if self.buyer_id.blank?
    self.payment_strategy_id = self.buyer&.payment_strategy_id

    compute_sum
  end

  after_create_commit :confirm_ordered!

  enum payment_status: {
    unpaid: 0,
    part_paid: 1,
    all_paid: 2,
    refunding: 3,
    refunded: 4,
    denied: 5
  }

  def extra
    {}
  end

  def subject
    order_items.map { |oi| oi.good&.name || 'Goods' }.join(', ')
  end

  def migrate_from_cart_item(cart_item_id)
    cart_item = CartItem.find cart_item_id
    self.user = cart_item.user
    self.buyer = user.buyer
    self.order_items.build(cart_item_id: cart_item_id, good_type: cart_item.good_type, good_id: cart_item.good_id, quantity: cart_item.quantity)

    cart_item.total_serve_charges.each do |serve_charge|
      self.order_serves.build(serve_charge_id: serve_charge.id, serve_id: serve_charge.serve_id, amount: serve_charge.subtotal)
    end
    cart_item.total_promote_charges.each do |promote_charge|
      self.order_promotes.build(promote_charge_id: promote_charge.id, promote_id: promote_charge.promote_id, amount: promote_charge.subtotal)
    end
    compute_sum
  end

  def migrate_from_cart_items(cart_item_ids: nil)
    cart_items = user.cart_items.checked.default_where(myself: self.myself)
    cart_items.each do |cart_item|
      self.order_items.build cart_item_id: cart_item.id, good_type: cart_item.good_type, good_id: cart_item.good_id, quantity: cart_item.quantity
    end
    init_with_default_serves
  end

  def init_with_default_serves(cart_item_ids: nil)
    summary = CartItem.checked_items(user_id: self.user_id, myself: self.myself)

    summary.promote_charges.each do |promote_charge|
      self.order_promotes.build(promote_charge_id: promote_charge.id, promote_id: promote_charge.promote_id, amount: promote_charge.subtotal)
    end
    summary.serve_charges.each do |serve_charge|
      self.order_serves.build(serve_charge_id: serve_charge.id, serve_id: serve_charge.serve_id, amount: serve_charge.subtotal)
    end
    compute_sum
  end

  def compute_sum
    _pure_order_serves = self.order_serves.select { |os| os.order_item_id.nil? }
    _pure_order_promotes = self.order_promotes.select { |op| op.order_item_id.nil? }
    
    self.pure_serve_sum = _pure_order_serves.sum { |o| o.amount }
    self.pure_promote_sum = _pure_order_promotes.sum { |o| o.amount }
    self.subtotal = self.order_items.sum { |o| o.amount }
    self.amount = self.subtotal.to_d + self.pure_serve_sum.to_d + self.pure_promote_sum.to_d
  end

  def promote_amount
    order_promotes.sum(:amount)
  end

  def serve_amount
    serve_promotes.sum(:amount)
  end

  def confirm_ordered!
    self.order_items.each do |oi|
      oi.confirm_ordered!
    end
  end

end
