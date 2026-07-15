# Cuánto vale un producto en un instante dado. ÚNICA fuente de verdad del
# cálculo del descuento: ni el Cart, ni el Checkout, ni las vistas repiten esta
# aritmética; todos preguntan acá.
#
# Es un PORO de solo lectura: se construye con (product, at:) y no toca la BD
# para escribir. Por eso vive en app/services como un verbo de dominio y no en
# el modelo.
class Pricing
  # at: el instante contra el que se evalúa la vigencia del descuento. Por
  # defecto "ahora" (catálogo y carrito), pero el Checkout le pasa un único
  # instante congelado para toda la orden.
  def initialize(product, at: Time.current)
    @product = product
    @at = at
  end

  # El descuento vigente aplicable, o nil si no hay ninguno.
  # Si varios se solapan sobre el mismo producto en @at, gana el de mayor
  # porcentaje (el solape está permitido a propósito).
  #
  # Filtra en memoria con active_at? (no el scope active_at) para aprovechar la
  # asociación precargada con includes(:discounts) y no hacer N+1 en catálogo y
  # carrito. Si discounts no viene precargada, se carga una sola vez acá.
  def discount
    return @discount if defined?(@discount)

    @discount = @product.discounts.select { |d| d.active_at?(@at) }.max_by(&:percentage)
  end

  # Precio de catálogo, sin descuento.
  def list_price
    @product.price
  end

  # Precio a pagar: list_price con el descuento aplicado, o list_price si no hay
  # descuento vigente.
  #
  # REDONDEO (único lugar donde ocurre): el dinero es entero (CLP). El descuento
  # se calcula en float y se redondea al peso con .round. NO se usa división
  # entera de Ruby: `8990 * 80 / 100` truncaría (7192.0 -> 7192 ok, pero
  # `8990 * 85 / 100` = 7641.5 debe dar 7642, no 7641). El .round evita ese sesgo
  # sistemático a favor del cliente.
  def unit_price
    return list_price if discount.nil?

    (list_price * (100 - discount.percentage) / 100.0).round
  end

  # ¿Hay descuento vigente? Azúcar para las vistas.
  def discounted?
    !discount.nil?
  end
end
