# frozen_string_literal: true

class Sellers::BaseController < ApplicationController
  before_action :authenticate_user!
  after_action :verify_authorized

  protected
    def set_time_range
      begin
        end_time = DateTime.parse(strip_timestamp_location(params[:end_time]))
        start_date = Date.parse(strip_timestamp_location(params[:start_time]))
      rescue StandardError
        end_time = DateTime.current
        start_date = end_time.to_date.ago(29.days).to_date
      end
      @start_date = start_date
      @end_date = end_time.to_date
    end
end
