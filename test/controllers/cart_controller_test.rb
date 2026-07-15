require "test_helper"

class CartControllerTest < ActionDispatch::IntegrationTest
  setup do
    @provider = Provider.create!(name: "Proveedor Test")
    @product  = Product.create!(provider: @provider, name: "Producto Test", price: 5000, stock: 10)
  end

  test "muestra el carrito vacío" do
    get cart_path

    assert_response :success
    assert_match "El carrito está vacío", response.body
  end

  test "agrega un producto al carrito" do
    post cart_items_path, params: { product_id: @product.id, quantity: 2 }

    assert_redirected_to cart_path
    assert_equal({ @product.id => 2 }, session[:cart])
    assert_equal "Agregaste #{@product.name} al carrito.", flash[:notice]
  end

  test "agregar dos veces el mismo producto acumula la cantidad" do
    post cart_items_path, params: { product_id: @product.id, quantity: 2 }
    post cart_items_path, params: { product_id: @product.id, quantity: 3 }

    assert_equal({ @product.id => 5 }, session[:cart])
  end

  test "una cantidad inválida muestra un mensaje y no rompe" do
    post cart_items_path, params: { product_id: @product.id, quantity: "abc" }

    assert_redirected_to cart_path
    assert_match "no es un entero válido", flash[:alert]
    assert_nil session[:cart]
  end

  test "una cantidad cero al agregar es rechazada" do
    post cart_items_path, params: { product_id: @product.id, quantity: 0 }

    assert_redirected_to cart_path
    assert_match "no es un entero válido", flash[:alert]
  end

  test "un producto inexistente muestra un mensaje y no rompe" do
    post cart_items_path, params: { product_id: 999_999, quantity: 1 }

    assert_redirected_to cart_path
    assert_match "no existe", flash[:alert]
  end

  test "actualiza la cantidad de un producto" do
    post cart_items_path, params: { product_id: @product.id, quantity: 2 }
    patch cart_item_path(@product), params: { quantity: 7 }

    assert_redirected_to cart_path
    assert_equal({ @product.id => 7 }, session[:cart])
    assert_match "Actualizaste", flash[:notice]
  end

  test "actualizar a cero quita el producto del carrito" do
    post cart_items_path, params: { product_id: @product.id, quantity: 2 }
    patch cart_item_path(@product), params: { quantity: 0 }

    assert_redirected_to cart_path
    assert_empty session[:cart]
    assert_match "Quitaste", flash[:notice]
  end

  test "quita un producto del carrito" do
    post cart_items_path, params: { product_id: @product.id, quantity: 2 }
    delete remove_cart_item_path(@product)

    assert_redirected_to cart_path
    assert_empty session[:cart]
    assert_match "Quitaste", flash[:notice]
  end

  test "el carrito sobrevive entre requests" do
    post cart_items_path, params: { product_id: @product.id, quantity: 2 }
    get cart_path

    assert_response :success
    assert_match @product.name, response.body
  end

  # --- Monto mínimo de compra ---

  test "confirmar la compra bajo el monto mínimo falla, no crea la orden y deja el carrito intacto" do
    Store.create!(name: "Tienda Test")
    @provider.update!(min_amount: 20_000)  # 2 x 5.000 no alcanza

    post cart_items_path, params: { product_id: @product.id, quantity: 2 }

    assert_no_difference [ "Order.count", "SubOrder.count", "OrderItem.count" ] do
      post checkout_path
    end

    assert_redirected_to cart_path
    assert_match "No se cumple con el monto mínimo de compra", flash[:alert]
    # El carrito no se vacía: el usuario puede agregar lo que le falta y reintentar.
    # (La sesión ya round-trippeó a JSON, así que sus claves vuelven como String:
    # se compara a través de Cart, que es quien las normaliza.)
    assert_equal({ @product.id => 2 }, Cart.new(session[:cart]).to_h)
  end

  test "el carrito muestra el precio de lista tachado y el descontado cuando hay descuento vigente" do
    Discount.create!(
      provider: @provider, name: "Promo", percentage: 20,
      starts_at: 1.hour.ago, ends_at: 1.hour.from_now, products: [ @product ]
    )
    post cart_items_path, params: { product_id: @product.id, quantity: 1 }

    get cart_path

    assert_response :success
    assert_match "list-price", response.body  # el precio de lista va tachado
    assert_match "$4.000",     response.body  # 5000 con 20% de descuento
    assert_match "(-20%)",     response.body
  end

  test "el carrito avisa cuánto falta para el mínimo del proveedor" do
    @provider.update!(min_amount: 20_000)
    post cart_items_path, params: { product_id: @product.id, quantity: 2 }

    get cart_path

    assert_response :success
    assert_match "Compra mínima", response.body
    assert_match "Faltan $10.000", response.body
  end

  test "confirmar la compra cumpliendo el mínimo crea la orden" do
    Store.create!(name: "Tienda Test")
    @provider.update!(min_amount: 20_000)

    post cart_items_path, params: { product_id: @product.id, quantity: 4 }  # 20.000

    assert_difference "Order.count", 1 do
      post checkout_path
    end

    assert_redirected_to order_path(Order.last)
    assert_nil session[:cart]
  end
end
