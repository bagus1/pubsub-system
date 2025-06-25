# db/migrate/xxx_create_orders.rb
class CreateOrders < ActiveRecord::Migration[7.0]
  def change
    create_table :orders do |t|
      t.integer :user_id, null: false
      t.decimal :total, precision: 10, scale: 2
      t.string :status, default: 'pending'
      t.timestamps
    end

    add_index :orders, :user_id
    add_index :orders, :status
  end
end