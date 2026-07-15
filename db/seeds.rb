# Seeds idempotentes: usan find_or_create_by! / find_or_initialize_by sobre
# atributos naturales, de modo que correrlos varias veces no duplica registros.

# 1 tienda
Store.find_or_create_by!(name: "Tienda Central")

# 2 proveedores, con montos mínimos de compra distintos: Sur exige un mínimo y
# Norte no (0 = sin mínimo), así se ven los dos casos en el flujo del carrito.
proveedor_norte = Provider.find_or_create_by!(name: "Distribuidora Norte")
proveedor_sur   = Provider.find_or_create_by!(name: "Distribuidora Sur")

proveedor_norte.update!(min_amount: 0)
proveedor_sur.update!(min_amount: 20_000)

# 3 productos por proveedor (6 en total), precios en CLP y stock variados.
productos = [
  { provider: proveedor_norte, name: "Café en grano 1kg",      price:  8990, stock: 120 },
  { provider: proveedor_norte, name: "Azúcar rubia 5kg",       price:  4500, stock:  40 },
  { provider: proveedor_norte, name: "Máquina de espresso",    price: 49900, stock:   8 },
  { provider: proveedor_sur,   name: "Vasos compostables x50", price:  1200, stock: 300 },
  { provider: proveedor_sur,   name: "Leche entera 1L",        price:  1100, stock: 200 },
  { provider: proveedor_sur,   name: "Molino industrial",      price: 38000, stock:  15 }
]

productos.each do |attrs|
  product = Product.find_or_initialize_by(provider: attrs[:provider], name: attrs[:name])
  product.update!(price: attrs[:price], stock: attrs[:stock])
end

# Descuentos. Idempotentes: se buscan por (provider, name) y se re-setean sus
# atributos y sus productos en cada corrida.
def seed_discount!(provider:, name:, percentage:, starts_at:, ends_at:, products:)
  discount = Discount.find_or_initialize_by(provider: provider, name: name)
  discount.assign_attributes(percentage: percentage, starts_at: starts_at, ends_at: ends_at)
  discount.products = products
  discount.save!
  discount
end

cafe   = Product.find_by!(provider: proveedor_norte, name: "Café en grano 1kg")
azucar = Product.find_by!(provider: proveedor_norte, name: "Azúcar rubia 5kg")
molino = Product.find_by!(provider: proveedor_sur,   name: "Molino industrial")
leche  = Product.find_by!(provider: proveedor_sur,   name: "Leche entera 1L")

# VIGENTE: 20% sobre dos productos de Norte, ventana amplia alrededor de hoy.
seed_discount!(
  provider:   proveedor_norte,
  name:       "Promo café + azúcar",
  percentage: 20,
  starts_at:  1.week.ago,
  ends_at:    1.week.from_now,
  products:   [ cafe, azucar ]
)

# VIGENTE: 10% sobre la leche de Sur, para ver un descuento activo también en el
# otro proveedor.
seed_discount!(
  provider:   proveedor_sur,
  name:       "Promo leche",
  percentage: 10,
  starts_at:  1.week.ago,
  ends_at:    1.week.from_now,
  products:   [ leche ]
)

# FUERA DE VENTANA (expirado): 15% sobre el molino de Sur, ya terminado.
seed_discount!(
  provider:   proveedor_sur,
  name:       "Liquidación molino (expirada)",
  percentage: 15,
  starts_at:  2.months.ago,
  ends_at:    1.month.ago,
  products:   [ molino ]
)

puts "Seeds listos: #{Store.count} tienda(s), #{Provider.count} proveedor(es), " \
     "#{Product.count} producto(s), #{Discount.count} descuento(s)."
