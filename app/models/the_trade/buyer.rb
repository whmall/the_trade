class Buyer < ApplicationRecord
  belongs_to :payment_strategy, optional: true
  has_many :users, foreign_key: :buyer_id, dependent: :nullify
  has_many :orders, foreign_key: :buyer_id, inverse_of: :buyer
  has_many :payment_references, foreign_key: :buyer_id, dependent: :destroy, autosave: true
  has_many :payment_methods, through: :payment_references, autosave: true
  has_many :cart_items, foreign_key: :buyer_id
  has_many :addresses, foreign_key: :buyer_id, dependent: :destroy
  has_many :promote_buyers, foreign_key: :buyer_id, dependent: :destroy
  has_many :promotes, ->{ special }, through: :promote_buyers

  scope :credited, -> { where(payment_strategy_id: self.credit_ids) }

  validates :deposit_ratio, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true

  def name_detail
    "#{name} (#{id})"
  end

  def last_overdue_date
    orders.order(overdue_date: :asc).first&.overdue_date
  end


  def last_overdue_date_new
    OrderItem.select(:order_id, :overdue_date).joins('left join orders on orders.id = order_items.order_id').to_pay.default_where('orders.buyer_id': self.id).where('order_items.state != 1').order(overdue_date: :asc).first&.overdue_date
  end

  def self.credit_ids
    PaymentStrategy.where.not(period: 0).pluck(:id)
  end

  # 逾期订单数量
  def overdue_order_item_count(time)
    OrderItem.joins(:order).to_pay.default_where('orders.buyer_id': self.id, 'overdue_date-lte': time).where('order_items.overdue_date < ?', Date.today).where('order_items.overdue_date is not null and order_items.state != 1').count
  end

  # 逾期订单金额(所有逾期订单明细的金额 + 对应订单的本土物流之类的总和) 前提 排除已收的
  def overdue_order_item_amount(time)
    amount = 0
    order_ids = []
    order_items= OrderItem.select(:order_id, :overdue_date, :amount).joins('left join orders on orders.id = order_items.order_id').to_pay.default_where('orders.buyer_id': self.id, 'overdue_date-lte': time).where('order_items.overdue_date < ?', Date.today).where('order_items.overdue_date is not null and order_items.state != 1')
    order_items.each do |item|
      amount += item.amount.to_d
      order_ids << item.order_id if item.order_id.to_i > 0
    end
    order_ids = order_ids.uniq
    if order_ids.length > 0
      orders = Order.select(:id, :pure_serve_sum, :received_pure_serve_sum).where(id: order_ids)  #逾期订单明细对应的客户订单
      orders.each do |order|
        amount += order.pure_serve_sum.to_d - order.received_pure_serve_sum.to_d
      end
    end

    return amount
  end


  # 应收订单数量
  def rereceive_overe_order_item_count
    OrderItem.joins(:order).to_pay.default_where('orders.buyer_id': self.id).where('order_items.state != 1').count
  end
end


# required attributes
# id
# :name
# :payment_strategy_id
# :deposit_ratio, :integer, default: 100, comment: '最小预付比例'
