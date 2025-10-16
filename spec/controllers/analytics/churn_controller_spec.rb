# frozen_string_literal: true

require "spec_helper"
require "shared_examples/sellers_base_controller_concern"
require "shared_examples/authorize_called"

RSpec.describe Analytics::ChurnController, type: :controller do
  let(:seller) { create(:named_seller) }

  include_context "with user signed in as admin for seller"

  before do
    allow(Feature).to receive(:active?).and_call_original
    allow(Feature).to receive(:active?).with(:churn_analytics, seller).and_return(true)
  end

  describe "GET #index" do
    it_behaves_like "inherits from Sellers::BaseController"

    it_behaves_like "authorize called for action", :get, :index do
      let(:record) { :churn }
    end

    it "renders successfully when authorized" do
      get :index
      expect(response).to have_http_status(:success)
    end

    context "when date range is provided" do
      it "renders successfully with date range parameters" do
        get :index, params: { start_time: 29.days.ago.to_date.to_s, end_time: Date.current.to_s }
        expect(response).to have_http_status(:success)
      end

      it "includes churn_data in Inertia props when date range provided" do
        get :index, params: { start_time: 29.days.ago.to_date.to_s, end_time: Date.current.to_s }
        expect(inertia.props[:churn_data]).to be_present
        expect(inertia.props[:churn_data]).to include(:start_date, :end_date, :metrics, :daily_data)
      end

      it "handles monthly aggregation parameter" do
        get :index, params: {
          start_time: 29.days.ago.to_date.to_s,
          end_time: Date.current.to_s,
          aggregate_by: "month"
        }
        expect(response).to have_http_status(:success)
      end

      it "handles invalid aggregate_by parameter" do
        get :index, params: {
          start_time: 29.days.ago.to_date.to_s,
          end_time: Date.current.to_s,
          aggregate_by: "invalid"
        }
        expect(response).to have_http_status(:success)
      end

      it "handles product_ids parameter" do
        get :index, params: {
          start_time: 29.days.ago.to_date.to_s,
          end_time: Date.current.to_s,
          product_ids: ["test-product"]
        }
        expect(response).to have_http_status(:success)
      end

      it "handles empty product_ids (no products selected)" do
        get :index, params: {
          start_time: 29.days.ago.to_date.to_s,
          end_time: Date.current.to_s,
          product_ids: []
        }
        expect(response).to have_http_status(:success)
      end

      it "handles date range exceeding 30 days" do
        get :index, params: {
          start_time: 40.days.ago.to_date.to_s,
          end_time: Date.current.to_s
        }
        expect(response).to have_http_status(:success)
      end
    end

    context "when feature flag is disabled" do
      before do
        allow(Feature).to receive(:active?).with(:churn_analytics, seller).and_return(false)
      end

      it "redirects with flash alert" do
        get :index
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
        get :index
        expect(response).to redirect_to("/dashboard")
        expect(flash[:alert]).to eq("You are not allowed to perform this action.")
      end
    end

    context "when user is not authenticated" do
      before do
        sign_out user_with_role_for_seller
      end

      it "redirects to login" do
        get :index
        expect(response).to redirect_to(login_path(next: analytics_churn_path))
      end
    end
  end
end

