class SyncStravaActivitiesJob < ApplicationJob
  queue_as :default

  def perform(user_id = nil)
    if user_id
      sync_user_activities(User.find(user_id))
    else
      StravaIntegration.where(active: true).find_each do |integration|
        sync_user_activities(integration.user)
      end
    end
  end

  private

  def sync_user_activities(user)
    return unless user.strava_connected?

    integration = user.strava_integration
    
    begin
      activities = integration.fetch_recent_activities(per_page: 30)

      activities.each do |strava_activity|
        user.activities.find_or_create_by(strava_activity_id: strava_activity.id.to_s) do |activity|
          activity.name = strava_activity.name
          activity.sport_type = strava_activity.sport_type
          activity.distance = strava_activity.distance
          activity.duration = strava_activity.elapsed_time
          activity.moving_time = strava_activity.moving_time
          activity.average_speed = strava_activity.average_speed
          activity.start_date = strava_activity.start_date
          activity.activity_data = strava_activity.to_h
        end
      end

      integration.update(last_sync_at: Time.current)
      
      Rails.logger.info "Synced #{activities.count} activities for user #{user.id}"
    rescue => e
      Rails.logger.error "Failed to sync Strava for user #{user.id}: #{e.message}"
    end
  end
end