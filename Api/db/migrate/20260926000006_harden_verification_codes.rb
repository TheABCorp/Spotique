class HardenVerificationCodes < ActiveRecord::Migration[8.1]
  def change
    # -- email: case-insensitive via citext --
    remove_index :verification_codes, name: "index_verification_codes_on_email_and_created_at"
    change_column :verification_codes, :email, :citext
    add_index :verification_codes, [:email, :created_at], where: "email IS NOT NULL"

    # -- phone format CHECK --
    add_check_constraint :verification_codes, "phone ~ '^\\+1\\d{10}$'",
                         name: "verification_codes_phone_e164_format"
  end
end
