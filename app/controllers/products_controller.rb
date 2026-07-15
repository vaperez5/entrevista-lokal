# Catálogo: el punto de entrada del flujo. Desde acá se agregan productos al
# carrito.
class ProductsController < ApplicationController
  def index
    # includes(:discounts) para que Pricing filtre los descuentos vigentes en
    # memoria, sin una consulta por producto.
    @products_by_provider = Product.includes(:provider, :discounts)
                                   .order(:id)
                                   .group_by(&:provider)
  end
end
