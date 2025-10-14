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
        { id: product.external_id, alive: product.alive?, unique_permalink: product.unique_permalink, name: product.name }
      end
    }
  end

  def serialize(data:, aggregate_by: CreatorAnalytics::Churn::AGGREGATE_BY_DAY)
    {
      start_date: data[:start_date],
      end_date: data[:end_date],
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
end
