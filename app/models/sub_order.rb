class SubOrder < ApplicationRecord
  belongs_to :order
  belongs_to :provider
  has_many :order_items, dependent: :destroy

  # Subtotal de la subórden: suma del line_total de sus items.
  def subtotal
    order_items.sum(&:line_total)
  end
end
