class HardenUsers < ActiveRecord::Migration[8.1]
  def change
    # -- email: case-insensitive via citext --
    remove_index :users, name: "index_users_on_email"
    change_column :users, :email, :citext
    add_index :users, :email, unique: true, where: "email IS NOT NULL"

    # -- phone format CHECK --
    add_check_constraint :users, "phone ~ '^\\+1\\d{10}$'", name: "users_phone_e164_format"

    # -- role CHECK --
    add_check_constraint :users, "role IN ('host', 'driver', 'both')", name: "users_role_valid"

    # -- rating_positive_pct → rating_positive_count --
    remove_column :users, :rating_positive_pct, :integer
    add_column :users, :rating_positive_count, :integer, default: 0, null: false
    add_check_constraint :users, "rating_positive_count >= 0 AND rating_positive_count <= rating_count",
                         name: "users_rating_positive_count_valid"

    # -- address string → structured columns --
    remove_column :users, :address, :string
    add_column :users, :street, :string
    add_column :users, :city, :string
    add_column :users, :state, :string
    add_column :users, :zip, :string
    add_column :users, :latitude, :decimal, precision: 10, scale: 7
    add_column :users, :longitude, :decimal, precision: 10, scale: 7
  end
end
