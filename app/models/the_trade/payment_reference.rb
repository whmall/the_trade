class PaymentReference < ApplicationRecord
  belongs_to :payment_method, inverse_of: :payment_references
  belongs_to :buyer, class_name: '::Buyer', foreign_key: :buyer_id, optional: true
  belongs_to :user, optional: true

  before_save :prevent_duplicate
  after_initialize if: :new_record? do |t|
    self.buyer_id = self.user&.buyer_id if self.buyer_id.nil?
  end

  def prevent_duplicate
    if PaymentReference.exists?(payment_method_id: self.payment_method_id, buyer_id: self.buyer_id)
      throw(:abort)
    end
  end

end
