class CreateAddresses < ActiveRecord::Migration[8.1]
  def change
    create_table :addresses, id: :uuid do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, type: :uuid
      t.string :label
      t.string :street, null: false
      t.string :city, null: false
      t.string :state, null: false
      t.string :zip, null: false
      t.decimal :latitude, precision: 10, scale: 7
      t.decimal :longitude, precision: 10, scale: 7

      t.timestamps
    end

    add_check_constraint :addresses, "label IN ('home', 'work', 'other')", name: "addresses_label_valid"

    remove_column :users, :street, :string
    remove_column :users, :city, :string
    remove_column :users, :state, :string
    remove_column :users, :zip, :string
    remove_column :users, :latitude, :decimal, precision: 10, scale: 7
    remove_column :users, :longitude, :decimal, precision: 10, scale: 7
  end
end
