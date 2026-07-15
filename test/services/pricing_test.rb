require "test_helper"

class PricingTest < ActiveSupport::TestCase
  setup do
    @norte = Provider.create!(name: "Norte")
    @cafe  = Product.create!(provider: @norte, name: "Café", price: 8_990, stock: 10)

    @now = Time.zone.local(2026, 7, 14, 12, 0, 0)
  end

  def discount!(percentage:, starts_at:, ends_at:, products: [ @cafe ])
    Discount.create!(
      provider: @norte, name: "Promo #{percentage}",
      percentage: percentage, starts_at: starts_at, ends_at: ends_at, products: products
    )
  end

  # --- Sin descuento ---

  test "sin descuento vigente el precio es el de lista" do
    pricing = Pricing.new(@cafe, at: @now)

    assert_nil pricing.discount
    assert_not pricing.discounted?
    assert_equal 8_990, pricing.list_price
    assert_equal 8_990, pricing.unit_price
  end

  # --- Vigencia ---

  test "un descuento vigente se aplica" do
    discount!(percentage: 20, starts_at: @now - 1.hour, ends_at: @now + 1.hour)
    pricing = Pricing.new(@cafe, at: @now)

    assert pricing.discounted?
    assert_equal 20, pricing.discount.percentage
    assert_equal 7_192, pricing.unit_price # 8990 * 0.80
  end

  test "un descuento fuera de la ventana no se aplica" do
    discount!(percentage: 20, starts_at: @now + 1.hour, ends_at: @now + 2.hours) # futuro
    assert_equal 8_990, Pricing.new(@cafe, at: @now).unit_price
  end

  test "en el instante de inicio aplica; en el de fin ya no" do
    discount!(percentage: 20, starts_at: @now, ends_at: @now + 1.hour)

    assert_equal 7_192, Pricing.new(@cafe, at: @now).unit_price               # inicio inclusivo
    assert_equal 8_990, Pricing.new(@cafe, at: @now + 1.hour).unit_price      # fin exclusivo
  end

  # --- Solape: gana el mayor porcentaje ---

  test "con dos descuentos vigentes que se solapan gana el de mayor porcentaje" do
    discount!(percentage: 10, starts_at: @now - 1.hour, ends_at: @now + 1.hour)
    discount!(percentage: 30, starts_at: @now - 1.hour, ends_at: @now + 1.hour)

    pricing = Pricing.new(@cafe, at: @now)

    assert_equal 30, pricing.discount.percentage
    assert_equal 6_293, pricing.unit_price # 8990 * 0.70
  end

  # --- Redondeo (único lugar) ---

  test "el precio con descuento se redondea al peso, no se trunca" do
    # 8990 con 15% de descuento = 8990 * 0.85 = 7641.5.
    # .round => 7642. La división entera de Ruby daría 7641 (trunca): mal.
    discount!(percentage: 15, starts_at: @now - 1.hour, ends_at: @now + 1.hour)

    assert_equal 7_642, Pricing.new(@cafe, at: @now).unit_price
    assert_not_equal 8_990 * 85 / 100, Pricing.new(@cafe, at: @now).unit_price # 7641, el truncado
  end
end
