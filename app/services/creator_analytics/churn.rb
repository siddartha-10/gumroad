# frozen_string_literal: true

class CreatorAnalytics::Churn
  include ActiveModel::Validations

  AGGREGATE_BY_DAY = "day"
  AGGREGATE_BY_MONTH = "month"
  AGGREGATE_OPTIONS = {
    AGGREGATE_BY_DAY => {
      title: "Daily",
      date_format: "yyyy-MM-dd"
    },
    AGGREGATE_BY_MONTH => {
      title: "Monthly",
      date_format: "yyyy-MM"
    },
  }.freeze

  WINDOW = 31
  CACHE_DAYS = 180

  validates :start_date, :end_date, presence: true
  validate :end_not_before_start
  validate :window_not_exceed_max

  attr_reader :start_date, :end_date

  def initialize(seller:, start_date:, end_date:, aggregate_by: AGGREGATE_BY_DAY, product_ids: nil)
    @seller = seller
    @start_date = start_date.to_date
    @end_date = end_date.to_date
    @aggregate_by = aggregate_by
    @product_external_ids = Array(product_ids).presence
  end

  def payload
    validate!
    series = daily_series

    data_points = if @aggregate_by == AGGREGATE_BY_MONTH
      monthly_points(series)
    else
      daily_points(series)
    end

    totals = totals_for_range(series, @start_date, @end_date)
    last_period = last_period_for_range(series, @start_date, @end_date)

    {
      start_date: @start_date.to_s,
      end_date: @end_date.to_s,
      metrics: {
        customer_churn_rate: totals[:customer_churn_rate],
        last_period_churn_rate: last_period[:customer_churn_rate],
        churned_subscribers: totals[:churned_subscribers],
        churned_mrr_cents: totals[:churned_mrr_cents]
      },
      daily_data: data_points
    }
  end

  private
    def end_not_before_start
      return if @start_date.blank? || @end_date.blank?
      errors.add(:end_date, "must be on or after start_date") if @end_date < @start_date
    end

    def window_not_exceed_max
      return if @start_date.blank? || @end_date.blank?
      days = (@end_date - @start_date).to_i + 1
      errors.add(:base, "date range cannot exceed #{WINDOW} days") if days > WINDOW
    end

    def daily_points(series)
      points = []
      (@start_date..@end_date).each do |date|
        window_start = date - (WINDOW - 1).days
        points << {
          date: date.to_s,
          customer_churn_rate: churn_rate_for_day(series, date),
          churned_subscribers: sum_hash_for_range(series[:churn_by_day], window_start, date),
          churned_mrr_cents: sum_hash_for_range(series[:churn_mrr_by_day], window_start, date)
        }
      end
      points
    end

    def monthly_points(series)
      points = []
      month_cursor = Date.new(@start_date.year, @start_date.month, 1)
      last_month_start = Date.new(@end_date.year, @end_date.month, 1)
      while month_cursor <= last_month_start
        period_start = [month_cursor, @start_date].max
        period_end = [month_cursor.end_of_month.to_date, @end_date].min
        metrics = totals_for_range(series, period_start, period_end)
        points << {
          date: Date.new(month_cursor.year, month_cursor.month, 1).to_s,
          customer_churn_rate: metrics[:customer_churn_rate],
          churned_subscribers: metrics[:churned_subscribers],
          churned_mrr_cents: metrics[:churned_mrr_cents]
        }
        month_cursor = month_cursor.next_month
      end
      points
    end

    def daily_series
      ext_from = (@start_date - (WINDOW - 1).days)
      range_days = (@end_date - @start_date).to_i + 1
      last_period_days = range_days
      last_start = @start_date - last_period_days.days
      base_from = [ext_from, last_start - (WINDOW - 1).days].min
      since = [base_from, CACHE_DAYS.days.ago.to_date].max
      to = Date.current

      Rails.cache.fetch(cache_key(since, to), expires_in: 24.hours) do
        compute_daily_series_for(since:, to:)
      end
    end

    def cache_key(since, to)
      product_key = @product_external_ids&.sort&.join(",") || "all"
      "seller_daily_churn_metrics:#{@seller.id}:v1:#{since}:#{to}:#{product_key}"
    end

    def base_subscription_scope
      subs = Subscription.where(seller: @seller)
      if @product_external_ids
        link_ids = Link.where(user: @seller, unique_permalink: @product_external_ids).pluck(:id)
        subs = subs.where(link_id: link_ids) if link_ids.any?
      end
      subs
    end

    def compute_daily_series_for(since:, to:)
      new_by_day = Hash.new(0)
      churn_by_day = Hash.new(0)
      churn_mrr_by_day = Hash.new(0)
      earliest_date = since - 30.days

      subs = base_subscription_scope

      base_active = subs.where("created_at < ?", since)
                        .where("deactivated_at IS NULL OR deactivated_at >= ?", since)
                        .count

      subs.where(created_at: since.beginning_of_day..to.end_of_day)
          .group("DATE(created_at)")
          .count
          .each { |d, c| new_by_day[d.to_date] = c }

      churned = subs.where("created_at <= ?", @end_date)
                    .where("deactivated_at IS NULL OR deactivated_at >= ?", earliest_date)
                    .where(deactivated_at: since.beginning_of_day..to.end_of_day)
                    .includes(last_payment_option: :price)
      churned.find_each do |s|
        d = s.deactivated_at.to_date
        churn_by_day[d] += 1
        price = s.last_payment_option&.price
        next if price.nil?
        mrr = case price.recurrence
              when BasePrice::Recurrence::MONTHLY then price.price_cents
              when BasePrice::Recurrence::YEARLY then (price.price_cents / 12.0).round
              when BasePrice::Recurrence::QUARTERLY then (price.price_cents / 3.0).round
              when BasePrice::Recurrence::BIANNUALLY then (price.price_cents / 6.0).round
              when BasePrice::Recurrence::EVERY_TWO_YEARS then (price.price_cents / 24.0).round
              else 0
              end
        churn_mrr_by_day[d] += mrr
      end

      active_by_day = {}
      running = base_active
      (since..to).each do |d|
        running += new_by_day[d]
        running -= churn_by_day[d]
        active_by_day[d] = running
      end

      {
        since: since,
        to: to,
        base_active_at_since: base_active,
        new_by_day: new_by_day,
        churn_by_day: churn_by_day,
        churn_mrr_by_day: churn_mrr_by_day,
        active_by_day: active_by_day
      }
    end

    def churn_rate_for_day(series, date)
      base_day = date - (WINDOW - 1).days
      base = active_at_start_of(series, base_day)
      new_30 = sum_hash_for_range(series[:new_by_day], date - (WINDOW - 1).days, date)
      churn_30 = sum_hash_for_range(series[:churn_by_day], date - (WINDOW - 1).days, date)
      calculate_churn_rate(churn_30, base, new_30)
    end

    def totals_for_range(series, from, to)
      churned_subscribers = sum_hash_for_range(series[:churn_by_day], from, to)
      churned_mrr_cents = sum_hash_for_range(series[:churn_mrr_by_day], from, to)
      new_in_range = sum_hash_for_range(series[:new_by_day], from, to)
      base_at_start = active_at_start_of(series, from)
      rate = calculate_churn_rate(churned_subscribers, base_at_start, new_in_range)
      {
        customer_churn_rate: rate,
        churned_subscribers: churned_subscribers,
        churned_mrr_cents: churned_mrr_cents
      }
    end

    def last_period_for_range(series, from, to)
      days = (to - from).to_i + 1
      last_end = from - 1.day
      last_start = last_end - (days - 1).days
      return { customer_churn_rate: 0.0 } if last_start > last_end
      totals_for_range(series, last_start, last_end)
    end

    # Helper method to sum hash values for a date range
    def sum_hash_for_range(hash, from, to)
      sum = 0
      (from..to).each { |d| sum += hash[d] }
      sum
    end

    # Helper method to calculate churn rate percentage
    def calculate_churn_rate(churned, base, new_subscriptions)
      denom = base + new_subscriptions
      return 0.0 if denom <= 0
      ((churned.to_f / denom) * 100).round(2)
    end

    def active_at_start_of(series, day)
      prev_day = day - 1
      if prev_day >= series[:since]
        series[:active_by_day][prev_day] || 0
      else
        series[:base_active_at_since]
      end
    end
end
