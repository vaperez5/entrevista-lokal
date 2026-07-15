class AddListPriceToOrderItems < ActiveRecord::Migration[8.0]
  # Precio de catálogo (sin descuento) congelado al momento de la compra.
  # unit_price sigue siendo el precio EFECTIVAMENTE PAGADO, ya con el descuento
  # aplicado; list_price deja registro de cuánto costaba a precio de lista para
  # poder mostrar el ahorro en la orden histórica.
  #
  # Se congela el RESULTADO, no la receta: la orden nunca recalcula el
  # descuento. Por eso NO guardamos discount_id acá (ver nota en OrderItem).
  def change
    add_column :order_items, :list_price, :integer
  end
end
