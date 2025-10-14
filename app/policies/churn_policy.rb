# frozen_string_literal: true

class ChurnPolicy < ApplicationPolicy
  def index?
    return false unless Feature.active?(:churn_analytics, seller)

    user.role_admin_for?(seller) ||
    user.role_marketing_for?(seller) ||
    user.role_support_for?(seller) ||
    user.role_accountant_for?(seller)
  rescue ActiveRecord::RecordNotFound
    false
  end

  def churn?
    index?
  end

  def churn_data?
    index?
  end
end
