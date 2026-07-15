# Tabla join entre Discount y Product.
class DiscountProduct < ApplicationRecord
  belongs_to :discount
  belongs_to :product
end
