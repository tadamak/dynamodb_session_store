# frozen_string_literal: true
class DashboardController < ApplicationController
  def index
    if session[:counter].blank?
      session[:counter] = 1
    else
      session[:counter] += 1
    end
    @message = session[:counter]
  end
end
