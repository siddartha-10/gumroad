# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Analytics Churn", type: :system, js: true do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  before do
    allow(Feature).to receive(:active?).and_call_original
    allow(Feature).to receive(:active?).with(:churn_analytics, user).and_return(true)
    allow(Feature).to receive(:active?).with(:churn_analytics, other_user).and_return(false)
  end

  describe "GET /analytics/churn" do
    context "when user is authenticated and authorized" do
      before { login_as user }

      it "renders the churn analytics page" do
        visit analytics_churn_path
        expect(page).to have_text("Analytics")
        expect(page).to have_text("Churn")
      end
    end

    context "when user is authenticated but not authorized" do
      before { login_as other_user }

      it "blocks access" do
        visit analytics_churn_path
        expect(page).to have_alert(text: "You are not allowed to perform this action.")
      end
    end

    context "when user is not authenticated" do
      it "redirects to login" do
        visit analytics_churn_path
        expect(current_url).to eq(login_url(host: Capybara.app_host, next: analytics_churn_path))
      end
    end
  end

  describe "redirect routes" do
    before { login_as user }

    it "redirects /dashboard/churn to /analytics/churn" do
      visit "/dashboard/churn"
      expect(page).to have_current_path(analytics_churn_path, ignore_query: true)
    end

    it "redirects /churn to /analytics/churn" do
      visit "/churn"
      expect(page).to have_current_path(analytics_churn_path, ignore_query: true)
    end
  end

  describe "feature flag behavior" do
    context "when feature flag is off" do
      before do
        allow(Feature).to receive(:active?).with(:churn_analytics, user).and_return(false)
        login_as user
      end

      it "blocks page access" do
        visit analytics_churn_path
        expect(page).to have_alert(text: "You are not allowed to perform this action.")
      end
    end
  end
end
