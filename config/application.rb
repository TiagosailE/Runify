require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)

module Runify
  class Application < Rails::Application

    config.load_defaults 8.1
    config.autoload_lib(ignore: %w[assets tasks])

    config.active_job.queue_adapter = :async

    config.after_initialize do
      if defined?(Rails::Server)
        Thread.new do
          loop do
            if Time.current.monday? && Time.current.hour == 6
              WeeklyAiAnalysisJob.perform_later
            end
            sleep 1.hour
          end
        end
      end
    end
  end
end
