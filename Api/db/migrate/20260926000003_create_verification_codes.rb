class CreateVerificationCodes < ActiveRecord::Migration[8.1]
  def change
    create_table :verification_codes do |t|
      t.string :phone
      t.string :email
      t.string :code_digest, null: false
      t.datetime :expires_at, null: false
      t.integer :attempts, default: 0, null: false
      t.datetime :verified_at

      t.datetime :created_at, null: false
    end

    add_index :verification_codes, [:phone, :created_at], where: "phone IS NOT NULL"
    add_index :verification_codes, [:email, :created_at], where: "email IS NOT NULL"

    reversible do |dir|
      dir.up do
        execute <<~SQL
          ALTER TABLE verification_codes
            ADD CONSTRAINT verification_codes_phone_or_email_present
            CHECK (phone IS NOT NULL OR email IS NOT NULL)
        SQL
      end
    end
  end
end
