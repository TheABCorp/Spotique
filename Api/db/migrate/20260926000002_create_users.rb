class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users, id: :uuid do |t|
      t.string :phone
      t.string :email
      t.string :first_name
      t.string :last_name
      t.string :address
      t.string :role
      t.string :payment_method_text
      t.integer :rating_positive_pct
      t.integer :rating_count, default: 0, null: false
      t.integer :no_show_count, default: 0, null: false

      t.timestamps
    end

    add_index :users, :phone, unique: true, where: "phone IS NOT NULL"
    add_index :users, :email, unique: true, where: "email IS NOT NULL"

    reversible do |dir|
      dir.up do
        execute <<~SQL
          ALTER TABLE users
            ADD CONSTRAINT users_phone_or_email_present
            CHECK (phone IS NOT NULL OR email IS NOT NULL)
        SQL
      end
    end
  end
end
