# Mínimo para que el checkout tenga a dónde redirigir. La vista real de la
# orden va en el incremento de vistas.
class OrdersController < ApplicationController
  def show
    @order = Order.includes(sub_orders: [ :provider, { order_items: :product } ])
                  .find(params[:id])
  end
end
