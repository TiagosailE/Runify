require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)

module Runify
  class Application < Rails::Application
    config.load_defaults 8.1
    config.autoload_lib(ignore: %w[assets tasks])

    config.i18n.default_locale = :"pt-BR"

    # Sem isso o Rails fica em UTC por padrao. "Hoje" so bate com o dia real
    # do usuario brasileiro se o app inteiro usar Date.current/Time.current
    # (que respeitam isto) em vez de Date.today/Time.now (que leem o
    # relogio do SO, UTC no container de producao).
    config.time_zone = "Brasilia"

    config.active_job.queue_adapter = :async

    # Remetente unico de todo e-mail do app (ApplicationMailer e Devise).
    # onboarding@resend.dev funciona sem verificar dominio proprio na Resend;
    # com dominio verificado, MAILER_FROM troca sem mexer no codigo.
    config.x.mailer_from = ENV["MAILER_FROM"].presence || "Runify <onboarding@resend.dev>"
  end
end
