class OrderItem < ApplicationRecord
  belongs_to :sub_order
  belongs_to :product

  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :unit_price, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Total de la línea: cantidad por precio unitario.
  def line_total
    quantity * unit_price
  end
end
