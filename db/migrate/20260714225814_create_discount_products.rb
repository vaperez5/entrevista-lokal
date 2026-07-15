class CreateDiscountProducts < ActiveRecord::Migration[8.0]
  # Tabla join entre Discount y Product: un descuento cubre uno o varios
  # productos, y un producto puede estar en varios descuentos.
  def change
    create_table :discount_products do |t|
      t.references :discount, null: false, foreign_key: true
      t.references :product,  null: false, foreign_key: true

      t.timestamps
    end

    # Un producto no debería aparecer dos veces en el mismo descuento.
    add_index :discount_products, [ :discount_id, :product_id ], unique: true
  end
end
