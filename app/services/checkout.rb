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

    # UN SOLO instante para toda la orden: con él se valúan los descuentos y se
    # congelan los precios. Si cada item consultara Time.current por su cuenta,
    # una compra que cruce el borde de una ventana de descuento podría congelar
    # unos items con descuento y otros sin él. Toda la orden se valúa en `at`.
    at = Time.current

    groups = grouped_priced_items(at)
    validate_minimums!(groups)

    order = ActiveRecord::Base.transaction do
      create_order!(groups)
    end

    Result.new(ok: true, order: order)
  rescue InvalidItem => e
    failure(e.message)
  rescue ActiveRecord::RecordInvalid => e
    failure(message_for(e.record))
  end

  private

  # Valida cada item, le calcula su Pricing en el instante `at` y agrupa por
  # proveedor. El precio con descuento sale de Pricing (fuente única); acá no se
  # recalcula nada. Valida antes de agrupar: el service es su propia frontera de
  # consistencia y no confía en que el Cart ya haya validado.
  def grouped_priced_items(at)
    @items.each { |item| validate_item!(item) }

    @items
      .map { |item| priced_item(item, at) }
      .group_by { |item| item[:product].provider_id }
  end

  def priced_item(item, at)
    pricing = Pricing.new(item[:product], at: at)

    {
      product:    item[:product],
      quantity:   item[:quantity],
      unit_price: pricing.unit_price,  # pagado, ya con descuento
      list_price: pricing.list_price   # catálogo del momento
    }
  end

  # El mínimo de compra es del PROVEEDOR, así que se evalúa contra el subtotal
  # POST-DESCUENTO de su subórden, no contra el total de la orden.
  #
  # Es todo o nada: basta que UN proveedor no llegue a su mínimo para que la
  # orden completa no se cree. Por eso se valida acá, antes de abrir la
  # transacción: no hay nada que revertir si ni siquiera empezamos.
  #
  # El Checkout revalida lo que el Cart ya validó a propósito: el service es su
  # propia frontera de consistencia y no confía en quien lo llama (un carrito
  # viejo en la sesión, otro cliente, un job).
  #
  # unit_price.to_i: un precio corrupto (nil, saltándose validaciones) no debe
  # reventar el chequeo del mínimo; su falla real la atrapa el create! del item.
  def validate_minimums!(groups)
    providers = Provider.where(id: groups.keys).index_by(&:id)

    errors = groups.filter_map do |provider_id, items|
      provider = providers.fetch(provider_id)
      subtotal = items.sum { |item| item[:quantity] * item[:unit_price].to_i }

      provider.minimum_error(subtotal) unless provider.minimum_met?(subtotal)
    end

    raise InvalidItem, errors.join(" ") if errors.any?
  end

  def create_order!(groups)
    order = Order.create!(store: @store)

    # Una subórden por cada proveedor distinto involucrado.
    groups.each do |provider_id, items|
      sub_order = order.sub_orders.create!(provider_id: provider_id)

      items.each do |item|
        # Precios CONGELADOS: se copia el RESULTADO ya calculado por Pricing.
        # La orden nunca vuelve a leer el catálogo ni recalcula el descuento; si
        # mañana el precio o el descuento cambian, esta orden no se altera.
        sub_order.order_items.create!(
          product:    item[:product],
          quantity:   item[:quantity],
          unit_price: item[:unit_price],
          list_price: item[:list_price]
        )
      end
    end

    order
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

  # El mensaje se deriva de los errores REALES del registro. No asumimos la
  # causa: si mañana falla unit_price, o cualquier validación nueva, el usuario
  # lee lo que de verdad pasó y no un diagnóstico inventado.
  def message_for(record)
    details = record.errors.full_messages.to_sentence.presence
    return "No se pudo confirmar la compra." if details.nil?

    case record
    when OrderItem
      "No se pudo agregar «#{record.product&.name}» a la orden: #{details}."
    else
      "No se pudo confirmar la compra: #{details}."
    end
  end

  def failure(message)
    Result.new(ok: false, error: message)
  end
end
