# cart_item
# good
class ServeFee
  attr_reader :good, :number, :buyer,
              :extra, :charges, :incoterms

  def initialize(good_type, good_id, number = 1, buyer_id = nil, extra = {})
    @good = good_type.constantize.unscoped.find good_id
    @number = number
    @buyer = Buyer.find(buyer_id) if buyer_id
    @incoterms = good.try(:incoterms) || Company.find_by(id:@buyer&.id)&.incoterms
    @extra = extra.merge! good.extra
    
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
      # 由于后台的Handling Fee是根据declare来的，所以默认给个值让他触发。
      if good.try(:declare).present? && good&.declare == "on_declare"
        charge = serve.compute_price(900, extra)
      elsif good.try(:declare).present? && good&.declare == "off_declare"
        charge = serve.compute_price(700, extra)
      else 
        charge = serve.compute_price(good.import_price.to_d, extra)
      end
    elsif serve.is_a? ExportRebateServe
      charge = serve.compute_price(good.import_price.to_d * number, extra)
      charge.subtotal = good.try(:declare).present? ?  (good&.declare == "off_declare" ? 0 :  good.import_price.to_d * number / 1.16 * 0.09 * -1  )  : charge.subtotal * good.import_price.to_d * number / 1.16 * 0.09 * -1  
      charge.subtotal = charge.subtotal.to_f.round(2)
    else
      charge = serve.compute_price(number, extra)
    end
    charge
  end

end
