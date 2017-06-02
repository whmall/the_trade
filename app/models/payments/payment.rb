class Payment < ApplicationRecord

  belongs_to :payment_method, optional: true
  has_many :payment_orders, dependent: :destroy
  has_many :orders, through: :payment_orders

  default_scope -> { order(created_at: :desc) }

  enum state: [
    :init,
    :completed
  ]


  def checked_amount
    payment_orders.sum(:check_amount)
  end

end

#  :id, :integer, limit: 4, null: false
#  :type, :string, limit: 255
#  :total_amount, :decimal, precision: 10, scale: 2
#  :order_amount, :decimal, precision: 10, scale: 2
#  :fee_amount, :decimal, precision: 10, scale: 2
#  :payment_uuid, :string, limit: 255
#  :notify_type, :string, limit: 255
#  :notified_at, :datetime, precision: 0
#  :pay_status, :string, limit: 255
#  :buyer_email, :string, limit: 255
#  :sign, :string, limit: 255
#  :seller_identifier, :string, limit: 255
#  :buyer_identifier, :string, limit: 255
#  :user_id, :integer, limit: 4
#  :currency, :string, limit: 255
#  :state, :integer, limit: 4, default: 0
#  :created_at, :datetime, precision: 0, null: false
#  :updated_at, :datetime, precision: 0, null: false