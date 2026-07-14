# Seeds idempotentes: usan find_or_create_by! / find_or_initialize_by sobre
# atributos naturales, de modo que correrlos varias veces no duplica registros.

# 1 tienda
Store.find_or_create_by!(name: "Tienda Central")

# 2 proveedores
proveedor_norte = Provider.find_or_create_by!(name: "Distribuidora Norte")
proveedor_sur   = Provider.find_or_create_by!(name: "Distribuidora Sur")

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

puts "Seeds listos: #{Store.count} tienda(s), #{Provider.count} proveedor(es), #{Product.count} producto(s)."
