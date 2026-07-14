# Confirma una compra: toma una lista plana de items y crea la Order con sus
# SubOrders (una por proveedor) y sus OrderItems, todo o nada.
#
# Es un verbo, una operación: por eso vive en app/services y no en app/models.
#
# No conoce HTTP, sesión ni Cart. Recibe items ya resueltos —
# [{ product: <Product>, quantity: <Integer> }, ...] — y una store. Eso lo hace
# testeable en aislamiento y lo deja libre de la forma en que el carrito guarde
# sus datos.
class Checkout
  # Result explícito en vez de excepciones hacia afuera: el controlador
  # pregunta `result.ok?` y decide. Un Struct alcanza y evita una dependencia;
  # el día que necesitemos más (múltiples errores, códigos) se puede crecer sin
  # cambiar la interfaz del service.
  Result = Struct.new(:ok, :order, :error, keyword_init: true) do
    def ok? = ok
  end

  # Error interno. NUNCA escapa del service: `call` lo rescata y lo convierte
  # en un Result de error. Lo usamos para abortar la transacción desde el
  # medio del recorrido y disparar el rollback.
  InvalidItem = Class.new(StandardError)

  EMPTY_CART   = "El carrito está vacío: agrega productos antes de confirmar la compra."
  MISSING_STORE = "No hay una tienda asociada a la compra."

  def initialize(store:, items:)
    @store = store
    @items = Array(items)
  end

  def call
    return failure(MISSING_STORE) if @store.nil?
    return failure(EMPTY_CART) if @items.empty?

    order = ActiveRecord::Base.transaction do
      create_order!
    end

    Result.new(ok: true, order: order)
  rescue InvalidItem => e
    failure(e.message)
  rescue ActiveRecord::RecordInvalid => e
    failure(message_for(e.record))
  end

  private

  def create_order!
    order = Order.create!(store: @store)

    # Una subórden por cada proveedor distinto involucrado.
    items_by_provider.each do |provider_id, items|
      sub_order = order.sub_orders.create!(provider_id: provider_id)

      items.each do |item|
        product = item[:product]

        sub_order.order_items.create!(
          product: product,
          quantity: item[:quantity],
          # Precio CONGELADO: se copia el valor de product.price en este
          # instante. Si mañana cambia el precio del producto, esta orden
          # sigue valiendo lo que valía hoy.
          unit_price: product.price
        )
      end
    end

    order
  end

  # Agrupa por provider_id. Valida cada item antes de agrupar: el service es su
  # propia frontera de consistencia y no confía en que el Cart ya haya validado.
  def items_by_provider
    @items.each { |item| validate_item!(item) }
    @items.group_by { |item| item[:product].provider_id }
  end

  def validate_item!(item)
    product  = item[:product]
    quantity = item[:quantity]

    unless product.is_a?(Product) && product.persisted?
      raise InvalidItem, "Hay un producto inválido en el carrito."
    end

    # Estricto a propósito: Integer, no "3" ni 2.7. La columna es integer y
    # castearía 2.7 => 2 silenciosamente, así que lo atajamos acá.
    unless quantity.is_a?(Integer) && quantity.positive?
      raise InvalidItem,
        "La cantidad para «#{product.name}» debe ser un número entero mayor que 0."
    end
  end

  def message_for(record)
    case record
    when OrderItem
      "La cantidad para «#{record.product&.name}» no es válida."
    else
      record.errors.full_messages.to_sentence.presence ||
        "No se pudo confirmar la compra."
    end
  end

  def failure(message)
    Result.new(ok: false, error: message)
  end
end
