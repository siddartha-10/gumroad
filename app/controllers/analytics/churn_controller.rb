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
    def set_time_range
      begin
        end_time = DateTime.parse(strip_timestamp_location(params[:end_time]))
        start_date = Date.parse(strip_timestamp_location(params[:start_time]))
      rescue StandardError
        end_time = DateTime.current
        start_date = end_time.to_date.ago(29.days).to_date
      end
      @start_date = start_date
      @end_date = end_time.to_date
    end

    def fetch_data_params
      {
        start_date: @start_date,
        end_date: @end_date,
        aggregate_by: params[:aggregate_by],
        product_ids: params[:product_ids]
      }
    end
end

