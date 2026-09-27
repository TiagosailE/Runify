class ApplicationMailer < ActionMailer::Base
  default from: Rails.configuration.x.mailer_from
  layout "mailer"
end
