# frozen_string_literal: true

require "spec_helper"

RSpec.describe CreatorAnalytics::Churn do
  let(:seller) { create(:user) }

  def series_stub(base_active: 100, date: Date.parse("2025-01-03"), new_count: 10, churn_count: 5, churn_mrr: 5000)
    since = Date.parse("2024-12-31")
    to = Date.parse("2025-01-31")
    new_by_day = Hash.new(0)
    churn_by_day = Hash.new(0)
    churn_mrr_by_day = Hash.new(0)
    active_by_day = {}
    new_by_day[date] = new_count
    churn_by_day[date] = churn_count
    churn_mrr_by_day[date] = churn_mrr
    {
      since: since,
      to: to,
      base_active_at_since: base_active,
      new_by_day: new_by_day,
      churn_by_day: churn_by_day,
      churn_mrr_by_day: churn_mrr_by_day,
      active_by_day: active_by_day,
      cum_new: {},
      cum_churn: {},
      cum_mrr: {},
    }
  end

  describe "payload (daily)" do
    it "computes 30-day rolling churn using base_at_start + new_in_window (factory-driven)" do
      start_date = Date.current - 10.days  # Use a recent date within cache window
      end_date = start_date

      product = create(:subscription_product, user: seller, price_cents: 100)

      # Base active: 100 subs created long before window, still active at window start
      base_subs = create_list(:subscription, 95, link: product, seller: seller, created_at: start_date - 60)
      churnable_subs = create_list(:subscription, 5, link: product, seller: seller, created_at: start_date - 60)
      churnable_subs.each { |s| s.update!(deactivated_at: start_date.to_time) }

      # New in window: 10 subs created within 30 days window
      create_list(:subscription, 10, link: product, seller: seller, created_at: start_date - 1)

      service = described_class.new(seller: seller, start_date:, end_date:, aggregate_by: described_class::AGGREGATE_BY_DAY)
      json = service.payload

      expect(json[:daily_data].length).to eq(1)
      expect(json[:metrics][:customer_churn_rate]).to be_within(0.01).of(4.55) # 5 / (100 + 10)
      point = json[:daily_data].first
      expect(point[:churned_subscribers]).to eq(5)
      expect(point[:churned_mrr_cents]).to eq(5 * 100)
    end
  end

  describe "payload (monthly)" do
    it "computes per-period churn using base at period start + new in period (factory-driven)" do
      start_date = Date.current - 10.days  # Use a recent date within cache window
      end_date = Date.current - 5.days
      product = create(:subscription_product, user: seller, price_cents: 100)

      # Base at period start: 100
      base_subs = create_list(:subscription, 100, link: product, seller: seller, created_at: start_date - 60)

      # New in period: 10
      create_list(:subscription, 10, link: product, seller: seller, created_at: start_date + 1)

      # Churn in period: 5
      churned = base_subs.sample(5)
      churned.each { |s| s.update!(deactivated_at: start_date + 2) }

      service = described_class.new(seller: seller, start_date:, end_date:, aggregate_by: described_class::AGGREGATE_BY_MONTH)
      json = service.payload
      expect(json[:daily_data].length).to eq(1)
      point = json[:daily_data].first
      expect(point[:customer_churn_rate]).to be_within(0.01).of(4.55)
      expect(json[:metrics][:customer_churn_rate]).to be_a(Float)
    end
  end

  describe "product filters" do
    it "accepts product_ids param without error" do
      start_date = Date.parse("2025-01-03")
      end_date = start_date
      service = described_class.new(seller: seller, start_date:, end_date:, aggregate_by: described_class::AGGREGATE_BY_DAY, product_ids: ["ext-1"])
      stub = series_stub
      allow_any_instance_of(described_class).to receive(:daily_series).and_return(stub)
      expect { service.payload }.not_to raise_error
    end
  end

  describe "caching" do
    it "uses Rails.cache to memoize computed daily series" do
      start_date = Date.parse("2025-01-03")
      end_date = Date.parse("2025-01-05")
      service = described_class.new(seller: seller, start_date:, end_date:, aggregate_by: described_class::AGGREGATE_BY_DAY)
      stub = series_stub
      expect(Rails.cache).to receive(:fetch).and_return(stub)
      json = service.payload
      expect(json).to include(:metrics, :daily_data)
    end
  end

  describe "validations and exclusions" do
    it "raises when date window exceeds 30 days" do
      start_date = Date.current - 40.days
      end_date = Date.current
      service = described_class.new(seller: seller, start_date:, end_date:)
      expect { service.payload }.to raise_error(ActiveModel::ValidationError)
    end

    it "raises when end date is before start date" do
      start_date = Date.current
      end_date = Date.current - 1
      service = described_class.new(seller: seller, start_date:, end_date:)
      expect { service.payload }.to raise_error(ActiveModel::ValidationError)
    end

    it "excludes subscriptions created after end_date even if deactivated within series window" do
      start_date = Date.current - 10.days
      end_date = Date.current - 5.days
      product = create(:subscription_product, user: seller, price_cents: 1000)

      # legitimate churn within window
      create(:subscription, link: product, seller: seller, created_at: start_date - 60.days, deactivated_at: start_date + 2.days)

      # future-created, deactivated within window (bad data) — should be excluded
      s = create(:subscription, link: product, seller: seller, created_at: end_date + 10.days)
      s.update_columns(deactivated_at: start_date + 5.days)

      json = described_class.new(seller: seller, start_date:, end_date:).payload
      expect(json[:metrics][:churned_subscribers]).to eq(1)
    end
  end
end
