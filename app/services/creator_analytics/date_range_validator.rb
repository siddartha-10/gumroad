# frozen_string_literal: true

class CreatorAnalytics::DateRangeValidator
  include ActiveModel::Validations

  attr_reader :start_date, :end_date, :max_window_days

  validates :start_date, :end_date, presence: true
  validate :end_not_before_start
  validate :window_not_exceed_max

  def initialize(start_date:, end_date:, max_window_days: 30)
    @start_date = start_date
    @end_date = end_date
    @max_window_days = max_window_days
  end

  private
    def end_not_before_start
      return if start_date.blank? || end_date.blank?
      errors.add(:end_date, "must be on or after start_date") if end_date < start_date
    end

    def window_not_exceed_max
      return if start_date.blank? || end_date.blank?
      days = (end_date - start_date).to_i
      errors.add(:base, "date range cannot exceed #{max_window_days} days") if days >= max_window_days
    end
end
