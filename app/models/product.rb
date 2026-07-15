class Product < ApplicationRecord
  belongs_to :provider
  has_many :discount_products, dependent: :destroy
  has_many :discounts, through: :discount_products

  validates :name, presence: true
  validates :price, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
