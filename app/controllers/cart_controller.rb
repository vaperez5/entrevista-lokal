# Traduce entre la sesión (HTTP) y la clase Cart (dominio).
# Toda la lógica del carrito vive en Cart; acá solo se carga, se muta y se
# persiste de vuelta.
class CartController < ApplicationController
  before_action :load_cart

  # Cantidad inválida o id corrupto: mensaje claro, no un 500.
  rescue_from Cart::Error, with: :redirect_with_error
  rescue_from ActiveRecord::RecordNotFound, with: :redirect_with_missing_product

  def show
    @items = @cart.items

    # Temporal: mientras no exista el catálogo real, listamos los productos acá
    # para poder agregarlos al carrito desde el browser. Se va cuando armemos
    # las vistas del flujo completo.
    @products = Product.includes(:provider).order(:id)
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

  private

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
