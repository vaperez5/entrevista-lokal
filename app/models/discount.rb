# Descuento porcentual que un proveedor aplica a uno o varios de sus productos,
# vigente en una ventana de tiempo [starts_at, ends_at).
#
# El CÁLCULO del precio con descuento NO vive acá: vive en Pricing (app/services),
# que es la única fuente de verdad. Este modelo solo define qué es un descuento,
# cuándo es válido y cuándo está vigente.
class Discount < ApplicationRecord
  belongs_to :provider
  has_many :discount_products, dependent: :destroy
  has_many :products, through: :discount_products

  validates :percentage, numericality: {
    only_integer: true, greater_than: 0, less_than_or_equal_to: 100
  }
  validate :ends_after_starts
  validate :products_belong_to_provider

  # Vigencia con inicio inclusivo y fin exclusivo: starts_at <= time < ends_at.
  # Así dos ventanas contiguas (una termina justo cuando empieza la otra) no se
  # solapan en el instante del borde.
  scope :active_at, ->(time) { where("starts_at <= ? AND ends_at > ?", time, time) }

  # La MISMA ventana que active_at, pero en memoria: permite a Pricing filtrar
  # sobre la asociación ya precargada (includes(:discounts)) sin disparar una
  # consulta por producto. Debe mantenerse en sincronía con el scope de arriba.
  def active_at?(time)
    starts_at <= time && time < ends_at
  end

  private

  def ends_after_starts
    return if starts_at.blank? || ends_at.blank?

    errors.add(:ends_at, "debe ser posterior a starts_at") if ends_at <= starts_at
  end

  # Un proveedor no puede descontar productos ajenos: todo producto del
  # descuento debe pertenecer al provider del descuento.
  def products_belong_to_provider
    return if provider.nil?

    ajenos = products.reject { |product| product.provider_id == provider_id }
    return if ajenos.empty?

    nombres = ajenos.map(&:name).join(", ")
    errors.add(:products, "no pertenecen al proveedor del descuento: #{nombres}")
  end
end
