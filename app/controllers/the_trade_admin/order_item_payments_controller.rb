class TheTradeAdmin::OrderItemPaymentsController < TheTradeAdmin::BaseController
  before_action :set_order_item
  before_action :set_payment_order, only: [:destroy]

  def index
    @payment_orders = @order_item.payment_orders
  end

  def new
    @payment_order = PaymentOrder.new
    @payments = @order_item.order_item_pending_payments
  end

  def create
    @payment_order = @order_item.payment_orders.build(payment_order_params)
    if @payment_order.save
      @payment_order.entity.save_audits operator_type: 'Manager', operator_id: current_manager.id, include: [:payment_orders]
      respond_to do |format|
        format.js
      end
    else
      render 'create_fail'
    end
  end

  def destroy
    if @payment_order.init?
      @payment_order.destroy
    end
    respond_to do |format|
      format.js
    end
  end

  private
  def set_payment_order
    @payment_order = PaymentOrder.find(params[:id])
  end

  def set_order_item
    @order_item = OrderItem.find(params[:order_id])
  end

  def payment_order_params
    params.fetch(:payment_order, {}).permit(:payment_id, :check_amount)
  end

end
