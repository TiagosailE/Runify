class HistoryController < ApplicationController
  before_action :authenticate_user!

  def index
    @filter = params[:filter] || 'all'
    @activities = filter_activities(@filter)
    @stats = calculate_stats(@activities)
    @monthly_data = calculate_monthly_data
  end

  private

  def filter_activities(filter)
    activities = current_user.activities.order(start_date: :desc)
    
    case filter
    when 'week'
      activities.where('start_date >= ?', 1.week.ago)
    when 'month'
      activities.where('start_date >= ?', 1.month.ago)
    when 'year'
      activities.where('start_date >= ?', 1.year.ago)
    else
      activities
    end
  end

  def calculate_stats(activities)
    {
      total_distance: activities.sum(:distance) / 1000.0,
      total_duration: activities.sum(:duration),
      total_activities: activities.count,
      average_pace: calculate_average_pace(activities)
    }
  end

  def calculate_average_pace(activities)
    return '--:--' if activities.empty?
    
    total_distance_km = activities.sum(:distance) / 1000.0
    total_time = activities.sum(:moving_time)
    
    return '--:--' if total_distance_km.zero?
    
    pace_seconds = (total_time / total_distance_km).to_i
    minutes = pace_seconds / 60
    seconds = pace_seconds % 60
    format("%d:%02d'", minutes, seconds)
  end

  def calculate_monthly_data
    last_6_months = 6.times.map { |i| i.months.ago.beginning_of_month }
    
    last_6_months.reverse.map do |month|
      activities = current_user.activities.where(
        start_date: month..month.end_of_month
      )
      
      {
        month: month.strftime('%b'),
        distance: (activities.sum(:distance) / 1000.0).round(1)
      }
    end
  end
end