class CreateDiscounts < ActiveRecord::Migration[8.0]
  def change
    create_table :discounts do |t|
      t.references :provider, null: false, foreign_key: true
      t.string   :name
      # Porcentaje entero: 1..100. Solo porcentaje: no hay monto fijo ni tipos.
      t.integer  :percentage, null: false
      # Ventana de vigencia [starts_at, ends_at): inicio inclusivo, fin
      # exclusivo (ver Discount.active_at).
      t.datetime :starts_at, null: false
      t.datetime :ends_at,   null: false

      t.timestamps
    end
  end
end
