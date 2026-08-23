source "https://rubygems.org"

gem "rails", "~> 8.1.1"

gem "propshaft"

gem "pg", "~> 1.1"

gem "puma", ">= 5.0"

gem "importmap-rails"

gem "turbo-rails"

gem "stimulus-rails"

gem "tailwindcss-rails"

gem "jbuilder"

gem "image_processing", "~> 2.0"

gem "aws-sdk-s3", require: false

gem "resend"

gem "tzinfo-data", platforms: %i[ windows jruby ]

gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

gem "bootsnap", require: false

gem "kamal", require: false

gem "thruster", require: false

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  gem "minitest", "< 6"

  gem "bundler-audit", require: false

  gem "brakeman", require: false

  gem "rubocop-rails-omakase", require: false
end

group :development do
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
  gem "simplecov", require: false
end

gem "devise", "~> 5.0"

gem "strava-ruby-client", "~> 3.0"

gem "dotenv-rails", "~> 3.2"

gem "gemini-ai", "~> 4.3"

gem "active_storage_validations", "~> 3.0"

# Parser de arquivos GPX/TCX importados manualmente (import de atividade)
gem "nokogiri"
