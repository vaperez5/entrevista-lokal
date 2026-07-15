class OrderItem < ApplicationRecord
  belongs_to :sub_order
  belongs_to :product

  # unit_price: lo EFECTIVAMENTE PAGADO (ya con descuento). list_price: el
  # precio de catálogo del momento. Ambos van congelados; ninguno se recalcula.
  #
  # A propósito NO guardamos discount_id: la orden congela el RESULTADO, no la
  # receta. Guardar el id acoplaría la orden histórica a la tabla mutable de
  # descuentos (que se puede editar o borrar) y abriría la puerta a recalcular.
  # El ahorro ya queda registrado como list_price - unit_price, que es todo lo
  # que la orden necesita mostrar.
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :unit_price, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :list_price, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # ¿Se compró con descuento? (el precio pagado quedó por debajo del de lista)
  def discounted?
    unit_price < list_price
  end

  # Total de la línea: cantidad por precio unitario (el pagado). Sin cambios.
  def line_total
    quantity * unit_price
  end
end
