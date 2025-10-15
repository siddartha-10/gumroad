# frozen_string_literal: true

class ChurnPresenter
  def initialize(seller:)
    @seller = seller
  end

  def page_props
    {
      has_subscription_products: has_subscription_products?,
      aggregate_options: aggregate_options_props,
      products: subscription_products.map do |product|
        { id: product.unique_permalink, alive: product.alive?, unique_permalink: product.unique_permalink, name: product.name }
      end
    }
  end

  # Fetch and serialize data for Inertia lazy loading
  def fetch_data_for_inertia(params)
    aggregate_by = normalize_aggregate_by(params[:aggregate_by])

    raw_data = CreatorAnalytics::Churn.new(
      seller: seller,
      start_date: params[:start_date],
      end_date: params[:end_date],
      aggregate_by: aggregate_by,
      product_ids: params[:product_ids]
    ).payload

    serialize(data: raw_data, aggregate_by: aggregate_by)
  rescue ActiveModel::ValidationError => e
    { errors: { base: [e.message] } }
  end

  def serialize(data:, aggregate_by:)
    {
      start_date: data[:start_date],
      end_date: data[:end_date],
      aggregate_by: aggregate_by,
      metrics: data[:metrics],
      daily_data: data[:daily_data]
    }
  end

  private
    attr_reader :seller

    def has_subscription_products?
      seller.products.alive.is_recurring_billing.exists?
    end

    def subscription_products
      @subscription_products ||= seller.products.alive.is_recurring_billing
    end

    def aggregate_options_props
      CreatorAnalytics::Churn::AGGREGATE_OPTIONS.map do |value, config|
        { value: value, title: config[:title] }
      end
    end

    def normalize_aggregate_by(value)
      CreatorAnalytics::Churn::AGGREGATE_OPTIONS.key?(value) ?
        value :
        CreatorAnalytics::Churn::AGGREGATE_BY_DAY
    end
end
