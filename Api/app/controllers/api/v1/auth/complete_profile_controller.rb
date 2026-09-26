module Api
  module V1
    module Auth
      class CompleteProfileController < ApplicationController
        include Authenticatable

        def create
          if current_user.profile_complete?
            return render json: { error: { message: "Profile already completed" } }, status: :conflict
          end

          current_user.assign_attributes(profile_params)
          missing = %i[first_name last_name address role].select { |f| current_user.send(f).blank? }

          if missing.any?
            details = missing.each_with_object({}) { |f, h| h[f] = ["can't be blank"] }
            return render json: { error: { message: "Validation failed", details: details } }, status: :unprocessable_entity
          end

          if current_user.save
            render json: { data: user_json(current_user) }, status: :created
          else
            render json: { error: { message: "Validation failed", details: current_user.errors.messages } }, status: :unprocessable_entity
          end
        end

        private

        def profile_params
          params.require(:user).permit(:first_name, :last_name, :address, :role)
        end

        def user_json(user)
          {
            id: user.id,
            phone: user.phone,
            email: user.email,
            first_name: user.first_name,
            last_name: user.last_name,
            address: user.address,
            role: user.role,
            payment_method_text: user.payment_method_text,
            rating_positive_pct: user.rating_positive_pct,
            rating_count: user.rating_count,
            no_show_count: user.no_show_count,
            created_at: user.created_at.iso8601,
            updated_at: user.updated_at.iso8601
          }
        end
      end
    end
  end
end
