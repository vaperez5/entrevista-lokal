# Catálogo: el punto de entrada del flujo. Desde acá se agregan productos al
# carrito.
class ProductsController < ApplicationController
  def index
    @products_by_provider = Product.includes(:provider)
                                   .order(:id)
                                   .group_by(&:provider)
  end
end
