class ApplicationMailer < ActionMailer::Base
  # onboarding@resend.dev funciona sem verificar dominio proprio na Resend.
  # Trocar por um endereco do dominio do Tiago quando ele tiver um
  # verificado (config em Resend > Domains).
  default from: "Runify <onboarding@resend.dev>"
  layout "mailer"
end
