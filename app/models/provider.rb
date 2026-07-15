class Provider < ApplicationRecord
  # El mensaje exacto que pide el negocio. Vive acá —y no duplicado en el Cart
  # y en el Checkout— porque la regla del mínimo es del proveedor: quien la
  # define debe definir también cómo se comunica cuando no se cumple.
  MINIMUM_NOT_MET = "No se cumple con el monto mínimo de compra"

  has_many :products
  has_many :discounts

  validates :min_amount, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # ¿El subtotal comprado a este proveedor alcanza su mínimo?
  # min_amount es 0 para quien no exige mínimo, así que esto es simplemente true.
  def minimum_met?(subtotal)
    subtotal >= min_amount
  end

  # Mensaje de error del mínimo, con el detalle de por qué no se cumple. El
  # prefijo es siempre MINIMUM_NOT_MET; lo que sigue es contexto para que el
  # usuario sepa cuánto le falta y a quién.
  def minimum_error(subtotal)
    "#{MINIMUM_NOT_MET}: «#{name}» exige un mínimo de #{clp(min_amount)} " \
      "y el subtotal es #{clp(subtotal)}."
  end

  private

  def clp(amount)
    "$#{ActiveSupport::NumberHelper.number_to_delimited(amount, delimiter: '.')}"
  end
end
