# frozen_string_literal: true

require "spec_helper"

RSpec.describe ChurnPresenter do
  let(:seller) { create(:user) }

  describe "page_props" do
    it "includes has_subscription_products, aggregate_options, and products list" do
      props = described_class.new(seller: seller).page_props
      expect(props).to include(:has_subscription_products, :aggregate_options, :products)
      expect(props[:has_subscription_products]).to eq(false)
      expect(props[:aggregate_options]).to be_an(Array)
      expect(props[:products]).to be_an(Array)
    end
  end

  describe "serialize" do
    it "returns shape expected by the frontend" do
      data = {
        start_date: "2025-01-01",
        end_date: "2025-01-31",
        metrics: { customer_churn_rate: 1.23, last_period_churn_rate: 2.34, churned_subscribers: 5, churned_mrr_cents: 1000 },
        daily_data: []
      }
      json = described_class.new(seller: seller).serialize(data: data, aggregate_by: "day")
      expect(json[:start_date]).to eq("2025-01-01")
      expect(json[:end_date]).to eq("2025-01-31")
      expect(json[:aggregate_by]).to eq("day")
      expect(json[:metrics]).to include(:customer_churn_rate, :last_period_churn_rate, :churned_subscribers, :churned_mrr_cents)
      expect(json[:daily_data]).to be_an(Array)
    end
  end

  describe "fetch_data_for_inertia" do
    let(:start_date) { 29.days.ago.to_date }
    let(:end_date) { Date.current }
    let(:params) do
      {
        start_date: start_date,
        end_date: end_date,
        aggregate_by: "day",
        product_ids: nil
      }
    end

    it "fetches and serializes churn data" do
      result = described_class.new(seller: seller).fetch_data_for_inertia(params)
      expect(result).to include(:start_date, :end_date, :metrics, :daily_data, :aggregate_by)
      expect(result[:aggregate_by]).to eq("day")
    end

    it "normalizes invalid aggregate_by to 'day'" do
      params[:aggregate_by] = "invalid"
      result = described_class.new(seller: seller).fetch_data_for_inertia(params)
      expect(result[:aggregate_by]).to eq("day")
    end

    it "handles validation errors gracefully" do
      params[:start_date] = 40.days.ago.to_date
      params[:end_date] = Date.current
      result = described_class.new(seller: seller).fetch_data_for_inertia(params)
      expect(result).to include(:errors)
      expect(result[:errors][:base]).to be_an(Array)
    end

    it "supports monthly aggregation" do
      params[:aggregate_by] = "month"
      result = described_class.new(seller: seller).fetch_data_for_inertia(params)
      expect(result[:aggregate_by]).to eq("month")
    end
  end
end
