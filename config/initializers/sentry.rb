# SENTRY_DSN no painel do Render. Sem a env var (dev/test, ou producao antes
# do Tiago criar o projeto na Sentry), o SDK vira no-op sozinho -- nao precisa
# de guarda condicional aqui.
Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]
  config.enabled_environments = %w[production]
  config.traces_sample_rate = 0.0
end
