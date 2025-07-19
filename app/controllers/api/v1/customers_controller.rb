# frozen_string_literal: true

module Api
  module V1
    class CustomersController < BaseController
      before_action :set_customer, only: %i[show update destroy]
      after_action :verify_authorized

      # GET /api/v1/customers
      def index
        authorize Customer
        customers = policy_scope(Customer).order(created_at: :desc)
        render json: customers, each_serializer: CustomerSerializer
      end

      # GET /api/v1/customers/:id
      def show
        authorize @customer
        render json: @customer, serializer: CustomerSerializer
      end

      # POST /api/v1/customers
      def create
        @customer = Current.agency.customers.new(customer_params)
        authorize @customer

        if @customer.save
          render json: @customer, serializer: CustomerSerializer, status: :created
        else
          render_validation_errors(@customer)
        end
      end

      # PATCH /api/v1/customers/:id
      def update
        authorize @customer

        if @customer.update(customer_params)
          render json: @customer, serializer: CustomerSerializer
        else
          render_validation_errors(@customer)
        end
      end

      # DELETE /api/v1/customers/:id
      def destroy
        authorize @customer

        if !@customer.is_active
          return render_error(
            key: "customers.already_deleted",
            message: "Клиент уже удалён",
            status: :unprocessable_entity,
            code: 422
          )
        end

        if @customer.update(is_active: false)
          render_success(
            key: "customers.deleted",
            message: "Клиент успешно удалён",
            code: 200
          )
        else
          render_validation_errors(@customer)
        end
      end

      private

      def set_customer
        @customer = Customer.find_by(id: params[:id])
        render_not_found("Клиент не найден", "customers.not_found") unless @customer
      end

      def customer_params
        params.require(:customer).permit(
          :first_name,
          :last_name,
          :middle_name,
          :service_type,
          :user_id,
          :notes,
          phones: [],
          names: [],
          property_ids: []
        )
      end
    end
  end
end
