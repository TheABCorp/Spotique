module Api
  module V1
    class UsersController < ApplicationController
      include Authenticatable
      include RequireCompleteProfile

      UPDATABLE_FIELDS = %i[first_name last_name role].freeze

      before_action :require_self!

      def show
        render json: { data: UserSerializer.call(current_user) }
      end

      def update
        attributes = update_params
        blank = attributes.keys.select { |field| attributes[field].blank? }

        if blank.any?
          details = blank.each_with_object({}) { |f, h| h[f] = [ "can't be blank" ] }
          return render json: { error: { message: "Validation failed", details: details } }, status: :unprocessable_entity
        end

        if current_user.update(attributes)
          render json: { data: UserSerializer.call(current_user) }
        else
          render json: { error: { message: "Validation failed", details: current_user.errors.messages } }, status: :unprocessable_entity
        end
      end

      private

      # Users can only read and update their own record.
      def require_self!
        return if params[:id].to_s.downcase == current_user.id

        render json: { error: { code: "forbidden", message: "You can only access your own user record." } }, status: :forbidden
      end

      def update_params
        params.require(:user).permit(*UPDATABLE_FIELDS)
      end
    end
  end
end
