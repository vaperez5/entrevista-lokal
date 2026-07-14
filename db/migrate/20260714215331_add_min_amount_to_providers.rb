class AddMinAmountToProviders < ActiveRecord::Migration[8.0]
  # Monto mínimo de compra del proveedor, en pesos chilenos enteros: la misma
  # unidad que product.price y order_item.unit_price.
  #
  # null: false, default: 0 => "sin mínimo" se modela como 0, no como NULL. Así
  # la comparación subtotal >= min_amount nunca tiene que lidiar con nil, ni en
  # el modelo ni en los proveedores que ya existían antes de esta columna.
  def change
    add_column :providers, :min_amount, :integer, null: false, default: 0
  end
end
