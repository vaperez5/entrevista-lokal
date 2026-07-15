module ApplicationHelper
  # El dinero se guarda como entero de pesos chilenos: sin decimales ni
  # centavos. Acá solo lo formateamos para mostrarlo.
  def clp(amount)
    "$#{number_with_delimiter(amount, delimiter: '.')}"
  end

  # Precio de un producto para catálogo y carrito, a partir de su Pricing.
  # Sin descuento vigente: el precio a secas. Con descuento: el precio de lista
  # tachado, el precio con descuento y el porcentaje. La presentación del
  # descuento vive en UN solo lugar para que ambas vistas se vean igual.
  def price_tag(pricing)
    return clp(pricing.unit_price) unless pricing.discounted?

    safe_join([
      content_tag(:span, clp(pricing.list_price), class: "list-price"),
      " ",
      content_tag(:strong, clp(pricing.unit_price)),
      content_tag(:span, " (-#{pricing.discount.percentage}%)", class: "discount-badge")
    ])
  end
end
