# frozen_string_literal: true

require "spec_helper"

describe ChurnPolicy do
  subject { described_class }

  let(:accountant_for_seller) { create(:user) }
  let(:admin_for_seller) { create(:user) }
  let(:marketing_for_seller) { create(:user) }
  let(:support_for_seller) { create(:user) }
  let(:owner_seller) { create(:named_seller) }
  let(:other_user) { create(:user) }

  before do
    create(:team_membership, user: accountant_for_seller, seller: owner_seller, role: TeamMembership::ROLE_ACCOUNTANT)
    create(:team_membership, user: admin_for_seller, seller: owner_seller, role: TeamMembership::ROLE_ADMIN)
    create(:team_membership, user: marketing_for_seller, seller: owner_seller, role: TeamMembership::ROLE_MARKETING)
    create(:team_membership, user: support_for_seller, seller: owner_seller, role: TeamMembership::ROLE_SUPPORT)
  end

  permissions :index? do
    context "when feature flag is off" do
      before do
        allow(Feature).to receive(:active?).and_call_original
        allow(Feature).to receive(:active?).with(:churn_analytics, owner_seller).and_return(false)
      end

      it "denies access for admin" do
        seller_context = SellerContext.new(user: admin_for_seller, seller: owner_seller)
        expect(subject).not_to permit(seller_context, :churn)
      end

      it "denies access for marketing" do
        seller_context = SellerContext.new(user: marketing_for_seller, seller: owner_seller)
        expect(subject).not_to permit(seller_context, :churn)
      end

      it "denies access for support" do
        seller_context = SellerContext.new(user: support_for_seller, seller: owner_seller)
        expect(subject).not_to permit(seller_context, :churn)
      end

      it "denies access for accountant" do
        seller_context = SellerContext.new(user: accountant_for_seller, seller: owner_seller)
        expect(subject).not_to permit(seller_context, :churn)
      end

      it "denies access for owner" do
        seller_context = SellerContext.new(user: owner_seller, seller: owner_seller)
        expect(subject).not_to permit(seller_context, :churn)
      end
    end

    context "when feature flag is on" do
      before do
        allow(Feature).to receive(:active?).and_call_original
        allow(Feature).to receive(:active?).with(:churn_analytics, owner_seller).and_return(true)
      end

      it "allows access for admin" do
        seller_context = SellerContext.new(user: admin_for_seller, seller: owner_seller)
        expect(subject).to permit(seller_context, :churn)
      end

      it "allows access for marketing" do
        seller_context = SellerContext.new(user: marketing_for_seller, seller: owner_seller)
        expect(subject).to permit(seller_context, :churn)
      end

      it "allows access for support" do
        seller_context = SellerContext.new(user: support_for_seller, seller: owner_seller)
        expect(subject).to permit(seller_context, :churn)
      end

      it "allows access for accountant" do
        seller_context = SellerContext.new(user: accountant_for_seller, seller: owner_seller)
        expect(subject).to permit(seller_context, :churn)
      end

      it "allows access for owner (admin role)" do
        seller_context = SellerContext.new(user: owner_seller, seller: owner_seller)
        expect(subject).to permit(seller_context, :churn)
      end

      it "denies access for other users" do
        seller_context = SellerContext.new(user: other_user, seller: owner_seller)
        expect(subject).not_to permit(seller_context, :churn)
      end

      it "allows access even without subscription products (placeholder path)" do
        # This tests that the policy doesn't check for subscription products
        # The empty state is handled in the presenter/frontend
        seller_context = SellerContext.new(user: admin_for_seller, seller: owner_seller)
        expect(subject).to permit(seller_context, :churn)
      end
    end
  end
end
