class RemoveDenormalizedColumnsFromUsers < ActiveRecord::Migration[8.1]
  def change
    remove_check_constraint :users, name: "users_rating_positive_count_valid"
    remove_column :users, :rating_positive_count, :integer, default: 0, null: false
    remove_column :users, :rating_count, :integer, default: 0, null: false
    remove_column :users, :no_show_count, :integer, default: 0, null: false
    remove_column :users, :payment_method_text, :string
  end
end
