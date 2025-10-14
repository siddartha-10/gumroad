# frozen_string_literal: true

require "spec_helper"
require "shared_examples/sellers_base_controller_concern"
require "shared_examples/authorize_called"

RSpec.describe AnalyticsController, type: :controller do
  let(:seller) { create(:named_seller) }

  include_context "with user signed in as admin for seller"

  before do
    allow(Feature).to receive(:active?).and_call_original
    allow(Feature).to receive(:active?).with(:churn_analytics, seller).and_return(true)
  end

  describe "GET #churn" do
    it_behaves_like "inherits from Sellers::BaseController"

    it_behaves_like "authorize called for action", :get, :churn do
      let(:record) { :churn }
    end

    it "renders successfully when authorized" do
      get :churn
      expect(response).to have_http_status(:success)
    end

    it "exposes has_subscription_products=false when user has none" do
      get :churn
      props = controller.instance_variable_get(:@churn_props)
      expect(props).to be_present
      expect(props[:has_subscription_products]).to eq(false)
    end

    context "when feature flag is disabled" do
      before do
        allow(Feature).to receive(:active?).with(:churn_analytics, seller).and_return(false)
      end

      it "redirects with flash alert" do
        get :churn
        expect(response).to redirect_to("/dashboard")
        expect(flash[:alert]).to eq("Your current role as Admin cannot perform this action.")
      end
    end

    context "when user is not authorized" do
      let(:other_user) { create(:user) }

      before do
        sign_out user_with_role_for_seller
        sign_in other_user
      end

      it "redirects with flash alert" do
        get :churn
        expect(response).to redirect_to("/dashboard")
        expect(flash[:alert]).to eq("You are not allowed to perform this action.")
      end
    end

    context "when user is not authenticated" do
      before do
        sign_out user_with_role_for_seller
      end

      it "redirects to login" do
        get :churn
        expect(response).to redirect_to(login_path(next: analytics_churn_path))
      end
    end
  end

  describe "GET #churn_data" do
    it_behaves_like "authorize called for action", :get, :churn_data do
      let(:record) { :churn }
      let(:request_params) { { start_time: 30.days.ago.to_date.to_s, end_time: Date.current.to_s } }
    end

    it "returns JSON with correct structure" do
      get :churn_data, params: { start_time: 29.days.ago.to_date.to_s, end_time: Date.current.to_s }
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include("application/json")
      json = JSON.parse(response.body)
      expect(json).to include("metrics", "daily_data", "start_date", "end_date")
    end

    it "returns monthly aggregated JSON when aggregate_by=month" do
      get :churn_data, params: { start_time: 29.days.ago.to_date.to_s, end_time: Date.current.to_s, aggregate_by: "month" }
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json).to include("metrics", "daily_data")
      expect(json["daily_data"]).to be_an(Array)
    end

    it "defaults to daily aggregation when aggregate_by is invalid" do
      get :churn_data, params: { start_time: 29.days.ago.to_date.to_s, end_time: Date.current.to_s, aggregate_by: "invalid" }
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json).to include("metrics", "daily_data")
    end

    it "handles missing date parameters gracefully" do
      get :churn_data
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json).to include("start_date", "end_date")
    end

    context "when feature flag is disabled" do
      before do
        allow(Feature).to receive(:active?).with(:churn_analytics, seller).and_return(false)
      end

      it "redirects with flash alert" do
        get :churn_data, params: { start_time: 30.days.ago.to_date.to_s, end_time: Date.current.to_s }
        expect(response).to redirect_to("/dashboard")
        expect(flash[:alert]).to eq("Your current role as Admin cannot perform this action.")
      end
    end

    context "when user is not authorized" do
      let(:other_user) { create(:user) }

      before do
        sign_out user_with_role_for_seller
        sign_in other_user
      end

      it "redirects with flash alert" do
        get :churn_data, params: { start_time: 30.days.ago.to_date.to_s, end_time: Date.current.to_s }
        expect(response).to redirect_to("/dashboard")
        expect(flash[:alert]).to eq("You are not allowed to perform this action.")
      end
    end
  end
end
