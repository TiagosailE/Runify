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

  def sync_user_activities(user)
    return { new_count: 0, updated_count: 0, error: nil } unless user.strava_connected?

    integration = user.strava_integration
    activities = integration.fetch_recent_activities(per_page: 30)
    new_count = 0
    updated_count = 0

    activities.each do |strava_activity|
      activity = user.activities.find_or_initialize_by(strava_activity_id: strava_activity.id.to_s)
      is_new = activity.new_record?

      activity.assign_attributes(
        name: strava_activity.name,
        sport_type: strava_activity.sport_type,
        distance: strava_activity.distance,
        duration: strava_activity.elapsed_time,
        moving_time: strava_activity.moving_time,
        average_speed: strava_activity.average_speed,
        start_date: strava_activity.start_date,
        activity_data: strava_activity.to_h,
        source: "strava"
      )

      if activity.save
        if is_new
          XpService.award_xp(user, activity) if defined?(XpService)
          new_count += 1
        else
          updated_count += 1
        end
      end
    end

    integration.update(last_sync_at: Time.current)
    Rails.logger.info "Synced #{activities.count} activities for user #{user.id}"

    { new_count: new_count, updated_count: updated_count, error: nil }
  rescue => e
    Rails.logger.error "Failed to sync Strava for user #{user.id}: #{e.message}"
    { new_count: 0, updated_count: 0, error: e }
  end
end
