require "test_helper"

class CheckoutTest < ActiveSupport::TestCase
  setup do
    @store = Store.create!(name: "Tienda Test")

    @norte = Provider.create!(name: "Distribuidora Norte")
    @sur   = Provider.create!(name: "Distribuidora Sur")

    @cafe   = Product.create!(provider: @norte, name: "Café en grano",   price:  8_990, stock: 100)
    @azucar = Product.create!(provider: @norte, name: "Azúcar rubia",    price:  4_500, stock: 100)
    @molino = Product.create!(provider: @sur,   name: "Molino industrial", price: 38_000, stock: 100)
  end

  # --- Agrupación por proveedor ---

  test "productos de dos proveedores generan una subórden por proveedor" do
    result = checkout(
      { product: @cafe,   quantity: 2 },  # Norte
      { product: @azucar, quantity: 1 },  # Norte
      { product: @molino, quantity: 3 }   # Sur
    )

    assert result.ok?
    assert_equal 2, result.order.sub_orders.count

    sub_norte = sub_order_for(result.order, @norte)
    sub_sur   = sub_order_for(result.order, @sur)

    assert_equal [ @cafe, @azucar ], sub_norte.order_items.map(&:product)
    assert_equal [ @molino ],        sub_sur.order_items.map(&:product)
  end

  test "productos de un solo proveedor generan una sola subórden" do
    result = checkout(
      { product: @cafe,   quantity: 2 },
      { product: @azucar, quantity: 1 }
    )

    assert result.ok?
    assert_equal 1, result.order.sub_orders.count
    assert_equal @norte, result.order.sub_orders.sole.provider
  end

  # --- Cálculos ---

  test "el subtotal de una subórden es la suma de quantity por unit_price de sus items" do
    result = checkout(
      { product: @cafe,   quantity: 2 },  # 2 * 8.990 = 17.980
      { product: @azucar, quantity: 1 },  # 1 * 4.500 =  4.500
      { product: @molino, quantity: 3 }   # 3 * 38.000 = 114.000
    )

    assert_equal 22_480,  sub_order_for(result.order, @norte).subtotal  # 17.980 + 4.500
    assert_equal 114_000, sub_order_for(result.order, @sur).subtotal
  end

  test "el total de la orden es la suma de los subtotales de sus subórdenes" do
    result = checkout(
      { product: @cafe,   quantity: 2 },
      { product: @azucar, quantity: 1 },
      { product: @molino, quantity: 3 }
    )

    assert_equal 136_480, result.order.total  # 22.480 (Norte) + 114.000 (Sur)
  end

  # --- Snapshot de precio ---

  test "cambiar el precio del producto no altera una orden ya creada" do
    order = checkout({ product: @cafe, quantity: 2 }).order
    assert_equal 17_980, order.total

    @cafe.update!(price: 99_999)
    order.reload

    assert_equal 8_990,  order.sub_orders.sole.order_items.sole.unit_price
    assert_equal 17_980, order.total
  end

  # --- Consistencia transaccional ---

  test "si la creación falla a mitad de camino no queda nada creado" do
    # El molino queda con price nil saltándose las validaciones de Product, así
    # que pasa el validate_item! del service y recién revienta en el create! del
    # OrderItem, cuando la Order y la subórden de Norte ya existen.
    @molino.update_column(:price, nil)

    before = counts

    result = checkout(
      { product: @cafe,   quantity: 2 },  # Norte: se crea... y debe revertirse
      { product: @molino, quantity: 3 }   # Sur: explota acá
    )

    assert_not result.ok?
    assert_nil result.order
    assert_equal before, counts
  end

  # --- Monto mínimo de compra ---

  test "un proveedor bajo su monto mínimo hace fallar la orden completa" do
    @sur.update!(min_amount: 100_000)  # el molino (38.000 x 1) no alcanza
    before = counts

    result = checkout(
      { product: @cafe,   quantity: 2 },  # Norte: sin mínimo, cumpliría
      { product: @molino, quantity: 1 }   # Sur: no llega al mínimo
    )

    assert_not result.ok?
    assert_nil result.order
    assert_match "No se cumple con el monto mínimo de compra", result.error
    assert_match @sur.name, result.error

    # Todo o nada: la subórden de Norte, que sí cumplía, tampoco se creó.
    assert_equal before, counts
  end

  test "el mínimo se mide contra el subtotal del proveedor, no contra el total de la orden" do
    @sur.update!(min_amount: 50_000)

    # El total del carrito (17.980 + 38.000 = 55.980) supera los 50.000, pero lo
    # que se le compra a Sur (38.000) no. Igual debe fallar.
    result = checkout(
      { product: @cafe,   quantity: 2 },
      { product: @molino, quantity: 1 }
    )

    assert_not result.ok?
    assert_match Provider::MINIMUM_NOT_MET, result.error
  end

  test "se reportan todos los proveedores que no cumplen el mínimo, no solo el primero" do
    @norte.update!(min_amount: 100_000)
    @sur.update!(min_amount: 100_000)

    result = checkout(
      { product: @cafe,   quantity: 1 },
      { product: @molino, quantity: 1 }
    )

    assert_not result.ok?
    assert_match @norte.name, result.error
    assert_match @sur.name,   result.error
  end

  test "alcanzar exactamente el mínimo es suficiente" do
    @sur.update!(min_amount: 76_000)  # 2 x 38.000

    result = checkout({ product: @molino, quantity: 2 })

    assert result.ok?
    assert_equal 76_000, result.order.total
  end

  test "un proveedor sin mínimo (0) no bloquea la compra" do
    assert_equal 0, @norte.min_amount

    result = checkout({ product: @cafe, quantity: 1 })

    assert result.ok?
  end

  # --- Entradas inválidas ---

  test "un carrito vacío falla con un mensaje claro y no crea nada" do
    before = counts

    result = Checkout.new(store: @store, items: []).call

    assert_not result.ok?
    assert_match "carrito está vacío", result.error
    assert_equal before, counts
  end

  test "una cantidad menor o igual a cero falla y no crea nada" do
    before = counts

    result = checkout({ product: @cafe, quantity: 0 })

    assert_not result.ok?
    assert_match "entero mayor que 0", result.error
    assert_equal before, counts
  end

  # --- Mensaje de error derivado de la causa real ---

  test "un error que no es de cantidad no se reporta como error de cantidad" do
    @molino.update_column(:price, nil)  # rompe unit_price, no quantity

    result = checkout({ product: @molino, quantity: 3 })

    assert_not result.ok?
    assert_no_match(/cantidad/i, result.error)
    assert_match @molino.name, result.error
    assert_match(/unit price/i, result.error)
  end

  private

  def checkout(*items)
    Checkout.new(store: @store, items: items).call
  end

  def sub_order_for(order, provider)
    order.sub_orders.find_by!(provider: provider)
  end

  def counts
    [ Order.count, SubOrder.count, OrderItem.count ]
  end
end
