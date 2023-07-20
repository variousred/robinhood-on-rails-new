class DashboardController < ApplicationController
  def home
    if params[:mfa_required].blank? && params[:challenge_required].blank? && @current_user.blank?
      Rails.logger.info("User is not logged in")
      # user just starting to log in, reset everything
      reset_session
      Rails.logger.info("Reset session")
    elsif current_user
      Rails.logger.info("User is logged in")
      get_portfolios
      @chart_data = portfolio_line_chart
    else
      Rails.logger.info("User is not logged in")
    end

  end
end
