# frozen_string_literal: true

class AnalyticsController < Sellers::BaseController
  before_action :set_time_range, only: %i[data_by_date data_by_state data_by_referral]

  after_action :set_dashboard_preference_to_sales, only: :index
  before_action :check_payment_details, only: [:index]

  layout "inertia", only: [:index]

  def index
    authorize :analytics

    @analytics_props = AnalyticsPresenter.new(seller: current_seller).page_props
    LargeSeller.create_if_warranted(current_seller)

    render inertia: "Analytics/Index",
           props: { analytics_props: @analytics_props }
  end

  def data_by_date
    authorize :analytics, :index?

    if Feature.active?(:use_creator_analytics_web_in_controller)
      data = creator_analytics_web.by_date
    else
      data = CreatorAnalytics::CachingProxy.new(current_seller).data_for_dates(@start_date, @end_date, by: :date)
    end
    render json: data
  end

  def data_by_state
    authorize :analytics, :index?

    if Feature.active?(:use_creator_analytics_web_in_controller)
      data = creator_analytics_web.by_state
    else
      data = CreatorAnalytics::CachingProxy.new(current_seller).data_for_dates(@start_date, @end_date, by: :state)
    end
    render json: data
  end

  def data_by_referral
    authorize :analytics, :index?

    if Feature.active?(:use_creator_analytics_web_in_controller)
      data = creator_analytics_web.by_referral
    else
      data = CreatorAnalytics::CachingProxy.new(current_seller).data_for_dates(@start_date, @end_date, by: :referral)
    end
    render json: data
  end

  protected
    def creator_analytics_web
      CreatorAnalytics::Web.new(user: current_seller, dates: (@start_date .. @end_date).to_a)
    end

    def set_title
      @title = "Analytics"
    end
end
