# Carrito de compras.
#
# Es un PORO (no hereda de ApplicationRecord): no se persiste en la BD, vive en
# la sesión. Envuelve el hash { product_id => quantity } y le da una API de
# dominio, de modo que la lógica no quede desparramada en el controlador.
#
# No conoce HTTP ni sesión: el controlador lo reconstruye con Cart.new(hash) y
# lo persiste de vuelta con #to_h. Esa es toda la frontera.
class Cart
  # Error base del carrito. El controlador rescata esto y lo traduce a un
  # mensaje para el usuario, en vez de reventar con un 500.
  Error = Class.new(StandardError)

  class InvalidQuantity < Error
    def initialize(value)
      super("La cantidad #{value.inspect} no es un entero válido.")
    end
  end

  class InvalidProductId < Error
    def initialize(value)
      super("El producto #{value.inspect} no es un identificador válido.")
    end
  end

  # Una línea del carrito con el Product ya resuelto desde la BD.
  Item = Struct.new(:product, :quantity, keyword_init: true) do
    def line_total
      quantity * product.price
    end
  end

  # source: el hash de la sesión. Sus claves llegan como String (la sesión se
  # serializa a JSON), así que se normalizan a Integer al entrar.
  def initialize(source = {})
    @quantities = normalize(source)
  end

  # Agrega el producto, o incrementa la cantidad si ya estaba.
  # quantity debe ser un entero > 0; si no, levanta InvalidQuantity.
  def add(product_id, quantity)
    qty = parse_quantity(quantity)
    raise InvalidQuantity, quantity unless qty.positive?

    id = parse_product_id(product_id)
    @quantities[id] = @quantities.fetch(id, 0) + qty
    self
  end

  # Fija la cantidad del producto. Si es <= 0, lo saca del carrito.
  # Una cantidad no numérica sigue siendo un error.
  def update(product_id, quantity)
    qty = parse_quantity(quantity)
    id  = parse_product_id(product_id)

    if qty.positive?
      @quantities[id] = qty
    else
      @quantities.delete(id)
    end
    self
  end

  def remove(product_id)
    @quantities.delete(parse_product_id(product_id))
    self
  end

  # Resuelve los ids contra la BD en una sola consulta (sin N+1). Los ids que
  # ya no existen —sesión vieja, producto borrado— se omiten en vez de romper.
  def items
    products = Product.where(id: @quantities.keys).includes(:provider).index_by(&:id)

    @quantities.filter_map do |product_id, quantity|
      product = products[product_id]
      Item.new(product: product, quantity: quantity) if product
    end
  end

  # Agrupa las líneas por proveedor. Es el MISMO criterio con el que Checkout
  # arma las subórdenes, y por eso es también el criterio con el que se evalúa
  # el mínimo de compra: el mínimo se mide contra el subtotal de cada proveedor,
  # no contra el total del carrito.
  def items_by_provider
    items.group_by { |item| item.product.provider }
  end

  # Mensajes de los proveedores cuyo subtotal no llega a su monto mínimo.
  # Vacío = el carrito se puede confirmar.
  #
  # Devuelve TODOS los incumplimientos, no el primero: si dos proveedores no
  # llegan al mínimo, el usuario se entera de los dos de una vez en lugar de
  # arreglar uno y toparse con el otro.
  def minimum_errors
    items_by_provider.filter_map do |provider, items|
      subtotal = items.sum(&:line_total)
      provider.minimum_error(subtotal) unless provider.minimum_met?(subtotal)
    end
  end

  def empty?
    @quantities.empty?
  end

  # El hash serializable que el controlador guarda de vuelta en la sesión.
  def to_h
    @quantities.dup
  end

  private

  # Al reconstruir desde la sesión no levantamos errores: si viene basura
  # (clave no numérica, cantidad corrupta) se descarta esa entrada. Una sesión
  # malformada no debe dejar al usuario con la app rota y sin salida.
  def normalize(source)
    (source || {}).each_with_object({}) do |(product_id, quantity), acc|
      id  = parse_product_id(product_id)
      qty = parse_quantity(quantity)
      acc[id] = qty if qty.positive?
    rescue Error
      next
    end
  end

  # Acepta 2 y "2"; rechaza "2.5", "abc", "", nil y floats.
  def parse_quantity(value)
    case value
    when Integer then value
    when String  then Integer(value, 10)
    else raise InvalidQuantity, value
    end
  rescue ArgumentError, TypeError
    raise InvalidQuantity, value
  end

  def parse_product_id(value)
    case value
    when Integer then value
    when String  then Integer(value, 10)
    else raise InvalidProductId, value
    end
  rescue ArgumentError, TypeError
    raise InvalidProductId, value
  end
end
