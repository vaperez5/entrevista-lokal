require "test_helper"

class DiscountTest < ActiveSupport::TestCase
  setup do
    @norte = Provider.create!(name: "Norte")
    @sur   = Provider.create!(name: "Sur")

    @cafe   = Product.create!(provider: @norte, name: "Café",   price: 8_990, stock: 10)
    @azucar = Product.create!(provider: @norte, name: "Azúcar", price: 4_500, stock: 10)
    @molino = Product.create!(provider: @sur,   name: "Molino", price: 38_000, stock: 10)

    @now = Time.zone.local(2026, 7, 14, 12, 0, 0)
  end

  def build_discount(**overrides)
    Discount.new({
      provider: @norte, name: "Promo", percentage: 20,
      starts_at: @now, ends_at: @now + 1.hour, products: [ @cafe ]
    }.merge(overrides))
  end

  # --- Validaciones ---

  test "un descuento bien formado es válido" do
    assert build_discount.valid?
  end

  test "percentage debe ser entero entre 1 y 100" do
    assert_not build_discount(percentage: 0).valid?
    assert_not build_discount(percentage: 101).valid?
    assert_not build_discount(percentage: -5).valid?
    assert build_discount(percentage: 1).valid?
    assert build_discount(percentage: 100).valid?
  end

  test "ends_at debe ser posterior a starts_at" do
    assert_not build_discount(starts_at: @now, ends_at: @now).valid?
    assert_not build_discount(starts_at: @now, ends_at: @now - 1.hour).valid?
    assert build_discount(starts_at: @now, ends_at: @now + 1.second).valid?
  end

  test "un proveedor no puede descontar productos de otro proveedor" do
    discount = build_discount(provider: @norte, products: [ @cafe, @molino ]) # @molino es de @sur

    assert_not discount.valid?
    assert_match(/no pertenecen al proveedor/, discount.errors[:products].to_sentence)
  end

  # --- Scope de vigencia: [starts_at, ends_at) ---

  test "active_at incluye el instante de inicio y excluye el de fin" do
    discount = build_discount(starts_at: @now, ends_at: @now + 1.hour)
    discount.save!

    assert_includes Discount.active_at(@now), discount               # inicio: inclusivo
    assert_includes Discount.active_at(@now + 30.minutes), discount   # dentro
    assert_not_includes Discount.active_at(@now + 1.hour), discount   # fin: exclusivo
    assert_not_includes Discount.active_at(@now - 1.second), discount # antes
  end
end
