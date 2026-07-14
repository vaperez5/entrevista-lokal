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
end
