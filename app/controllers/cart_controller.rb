# Traduce entre la sesión (HTTP) y la clase Cart (dominio).
# Toda la lógica del carrito vive en Cart; acá solo se carga, se muta y se
# persiste de vuelta.
class CartController < ApplicationController
  before_action :load_cart

  # Cantidad inválida o id corrupto: mensaje claro, no un 500.
  rescue_from Cart::Error, with: :redirect_with_error
  rescue_from ActiveRecord::RecordNotFound, with: :redirect_with_missing_product

  def show
    # Cart#items resuelve los Product REALES desde la BD, así que product.price
    # y el line_total del carrito son los precios VIVOS del catálogo. El
    # congelado recién ocurre al confirmar la compra, dentro de Checkout.
    #
    # El agrupado se arma acá y no en la vista: la vista solo itera lo que
    # recibe. Además así el agrupado del carrito queda al lado del agrupado que
    # hará Checkout, y es evidente que ambos usan el mismo criterio (proveedor).
    items = @cart.items

    @items_by_provider = items.group_by { |item| item.product.provider }
    @total = items.sum(&:line_total)
  end

  def add_item
    product = Product.find(params[:product_id])
    @cart.add(product.id, params[:quantity])
    save_cart

    redirect_to cart_path, notice: "Agregaste #{product.name} al carrito."
  end

  def update_item
    product = Product.find(params[:product_id])
    @cart.update(product.id, params[:quantity])
    save_cart

    notice = if @cart.to_h.key?(product.id)
      "Actualizaste la cantidad de #{product.name}."
    else
      "Quitaste #{product.name} del carrito."
    end

    redirect_to cart_path, notice: notice
  end

  def remove_item
    product = Product.find(params[:product_id])
    @cart.remove(product.id)
    save_cart

    redirect_to cart_path, notice: "Quitaste #{product.name} del carrito."
  end

  # Traduce el Cart de la sesión a la lista plana que espera Checkout, delega,
  # y decide qué hacer según el Result. Ninguna lógica de negocio vive acá.
  def checkout
    result = Checkout.new(store: current_store, items: checkout_items).call

    if result.ok?
      session.delete(:cart)
      redirect_to order_path(result.order), notice: "¡Compra confirmada! Orden ##{result.order.id}."
    else
      redirect_to cart_path, alert: result.error
    end
  end

  private

  def checkout_items
    @cart.items.map { |item| { product: item.product, quantity: item.quantity } }
  end

  # Placeholder: todavía no hay autenticación ni concepto de "tienda actual",
  # así que usamos la única tienda de los seeds. Cuando exista login, esto pasa
  # a salir de la sesión del usuario.
  def current_store
    Store.first
  end

  def load_cart
    @cart = Cart.new(session[:cart])
  end

  def save_cart
    session[:cart] = @cart.to_h
  end

  def redirect_with_error(exception)
    redirect_to cart_path, alert: exception.message
  end

  def redirect_with_missing_product
    redirect_to cart_path, alert: "El producto que intentas modificar no existe."
  end
end
