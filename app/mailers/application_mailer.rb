class ApplicationMailer < ActionMailer::Base
  # onboarding@resend.dev funciona sem verificar dominio proprio na Resend.
  default from: "Runify <onboarding@resend.dev>"
  layout "mailer"
end
