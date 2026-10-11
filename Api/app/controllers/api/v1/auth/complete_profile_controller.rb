module Api
  module V1
    module Auth
      class CompleteProfileController < ApplicationController
        include Authenticatable

        REQUIRED_FIELDS = %i[first_name last_name role].freeze

        def create
          if current_user.profile_complete?
            return render json: { error: { message: "Profile already completed" } }, status: :conflict
          end

          current_user.assign_attributes(profile_params)
          missing = REQUIRED_FIELDS.select { |f| current_user.send(f).blank? }
          address = address_params
          missing << :address if address.blank?

          if missing.any?
            details = missing.each_with_object({}) { |f, h| h[f] = [ "can't be blank" ] }
            return render json: { error: { message: "Validation failed", details: details } }, status: :unprocessable_entity
          end

          current_user.addresses.build(address)

          if current_user.save
            render json: { data: UserSerializer.call(current_user) }, status: :created
          else
            render json: { error: { message: "Validation failed", details: current_user.errors.messages } }, status: :unprocessable_entity
          end
        end

        private

        def profile_params
          params.require(:user).permit(:first_name, :last_name, :role)
        end

        def address_params
          address = params.require(:user)[:address]
          return unless address.respond_to?(:permit)

          address.permit(:label, :street, :city, :state, :zip, :latitude, :longitude)
        end
      end
    end
  end
end
