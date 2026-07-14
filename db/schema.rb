# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_07_14_215331) do
  create_table "order_items", force: :cascade do |t|
    t.integer "sub_order_id", null: false
    t.integer "product_id", null: false
    t.integer "quantity"
    t.integer "unit_price"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_order_items_on_product_id"
    t.index ["sub_order_id"], name: "index_order_items_on_sub_order_id"
  end

  create_table "orders", force: :cascade do |t|
    t.integer "store_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["store_id"], name: "index_orders_on_store_id"
  end

  create_table "products", force: :cascade do |t|
    t.integer "provider_id", null: false
    t.string "name"
    t.integer "price"
    t.integer "stock"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["provider_id"], name: "index_products_on_provider_id"
  end

  create_table "providers", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "min_amount", default: 0, null: false
  end

  create_table "stores", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "sub_orders", force: :cascade do |t|
    t.integer "order_id", null: false
    t.integer "provider_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_sub_orders_on_order_id"
    t.index ["provider_id"], name: "index_sub_orders_on_provider_id"
  end

  add_foreign_key "order_items", "products"
  add_foreign_key "order_items", "sub_orders"
  add_foreign_key "orders", "stores"
  add_foreign_key "products", "providers"
  add_foreign_key "sub_orders", "orders"
  add_foreign_key "sub_orders", "providers"
end
