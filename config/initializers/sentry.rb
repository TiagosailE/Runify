# Sem SENTRY_DSN o SDK vira no-op sozinho -- nao precisa de guarda condicional.
Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]
  config.enabled_environments = %w[production]
  config.traces_sample_rate = 0.0
end
