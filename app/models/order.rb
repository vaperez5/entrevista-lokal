class Order < ApplicationRecord
  belongs_to :store
  has_many :sub_orders, dependent: :destroy

  # Total de la orden: suma de los subtotales de sus subórdenes.
  def total
    sub_orders.sum(&:subtotal)
  end
end
