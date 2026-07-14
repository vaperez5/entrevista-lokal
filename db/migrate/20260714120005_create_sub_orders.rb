class CreateSubOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :sub_orders do |t|
      t.references :order, null: false, foreign_key: true
      t.references :provider, null: false, foreign_key: true

      t.timestamps
    end
  end
end
