namespace :strava do
  desc "Refresh Strava tokens for integrations nearing expiry"
  task refresh_tokens: :environment do
    RefreshStravaTokensJob.perform_now
  end
end
