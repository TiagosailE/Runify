class RefreshStravaTokensJob < ApplicationJob
  queue_as :default

  def perform
    StravaIntegration.where(active: true).find_each do |integration|
      begin
        integration.refresh_token! if integration.token_needs_refresh?
      rescue => e
        Rails.logger.error("RefreshStravaTokensJob: failed for integration #{integration.id}: #{e.message}")
      end
    end
  end
end
