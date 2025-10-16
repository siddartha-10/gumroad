# frozen_string_literal: true

class Analytics::ChurnController < Sellers::BaseController
  before_action :set_time_range, only: [:index]
  before_action :check_payment_details, only: [:index]

  layout "inertia", only: [:index]

  def index
    authorize :churn

    presenter = ChurnPresenter.new(seller: current_seller)

    props = {
      churn_props: presenter.page_props
    }

    # Lazy load churn data when date range is provided (Inertia partial reload)
    if params[:start_time].present? && params[:end_time].present?
      props[:churn_data] = -> { presenter.fetch_data_for_inertia(fetch_data_params) }
    end

    LargeSeller.create_if_warranted(current_seller)

    render inertia: "Churn/Index", props: props
  end

  protected
    def fetch_data_params
      product_ids = if params.key?(:product_ids)
                      ids = params[:product_ids]
                      ids = ids.to_unsafe_h.values.flatten if ids.is_a?(ActionController::Parameters) || ids.is_a?(Hash)
                      ids = Array(ids).map(&:to_s).compact
                      ids.empty? ? nil : ids
                    else
                      nil
                    end
      {
        start_date: @start_date,
        end_date: @end_date,
        aggregate_by: params[:aggregate_by],
        product_ids: product_ids
      }
    end
end

