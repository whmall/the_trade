class TheTradeAdmin::PaymentsController < TheTradeAdmin::BaseController
  before_action :set_payment, only: [:show, :edit, :update, :analyze, :adjust, :destroy]

  def dashboard

  end

  def index
    @payments = Payment.default_where(params.permit(:type, :state, :'payment_orders.state', :id, :team_id))
      .default_where(params.fetch(:q, {}).permit(:'buyer_name-like', :buyer_identifier, :buyer_bank, :payment_uuid))
      .permit_with(the_role_user)
    if params[:q].present?
      if params[:q][:uuid].present?
        @payments = @payments.joins("left join payment_orders a on a.payment_id = payments.id left join orders b on b.id = a.entity_id and a.entity_type = 'Order' left join order_items c on c.id = a.entity_id and a.entity_type = 'OrderItem' ").where('b.uuid = ? or c.order_item_no = ?', params[:q][:uuid], params[:q][:uuid])
      end
    end
    @payments = @payments.order(id: :desc).page(params[:page])

  end

  def show
  end

  def new
    @payment = Payment.new
  end

  def create
    @payment = Payment.new(payment_params.merge(creator_id: the_role_user.id, team_id: current_manager.team_id&.first))

    if @payment.save
      redirect_to admin_payments_url, notice: 'Payment was successfully created.'
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @payment.update(payment_params)
      redirect_to admin_payments_url, notice: 'Payment was successfully updated.'
    else
      render :edit
    end
  end

  def analyze
    @payment.analyze_payment_method

    respond_to do |format|
      format.js
    end
  end

  def adjust
    @payment.analyze_adjust_amount
    respond_to do |format|
      format.js
      format.html { redirect_to admin_payments_url, notice: 'Payment was successfully updated.' }
    end
  end

  def destroy
    @payment.destroy
    redirect_to admin_payments_url, notice: 'Payment was successfully destroyed.'
  end

  private
  def set_payment
    @payment = Payment.find(params[:id])
  end

  def payment_params
    p = params.fetch(:payment, {}).permit(:type,
                                          :payment_uuid,
                                          :total_amount,
                                          :fee_amount,
                                          :income_amount,
                                          :notified_at,
                                          :comment,
                                          :buyer_name,
                                          :buyer_identifier,
                                          :buyer_bank
    )
    p.reverse_merge(type: 'BankPayment')
  end

end