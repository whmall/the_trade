# cart_item
# good
class ServeFee
  attr_reader :good, :number, :buyer,
              :extra, :charges, :incoterms

  def initialize(good_type, good_id, number = 1, buyer_id = nil, extra = {})
    @good = good_type.constantize.unscoped.find good_id
    @number = number
    @buyer = Buyer.find(buyer_id) if buyer_id
    @extra = extra.merge! good.extra
    @incoterms = good.try(:incoterms) || @buyer&.incoterms
    p @buyer&.incoterms
    p "abd"*100
    verbose_fee
  end

  def verbose_fee
    @charges = []

    Serve.single.overall.default.each do |serve|
      charge = get_charge(serve)
      @charges << charge
    end

    @charges
  end

  def subtotal
    @subtotal ||= self.charges.map(&:subtotal).sum
  end

  def get_charge(serve)
    if serve.name == "Global Shipping" && incoterms == "fob"
      charge = serve.charges.build
      charge.subtotal = 0
    elsif serve.is_a? QuantityServe
      charge = serve.compute_price(good.unified_quantity * number, extra)
    elsif serve.is_a? NumberServe
      charge = serve.compute_price(number, extra)
    elsif serve.is_a? TpServe
      charge = serve.compute_price(good.price.to_d, extra)
    elsif serve.is_a? ExportRebateServe
      charge = serve.compute_price(good.price.to_d * number, extra)
      charge.subtotal = good.declare.present? ?  (good.declare == "off_declare" ? 0 :  good.price.to_d * number / 1.16 * 0.09 * -1  )  : charge.subtotal * good.price.to_d * number / 1.16 * 0.09 * -1  
    else
      charge = serve.compute_price(number, extra)
    end
    charge
  end

end
