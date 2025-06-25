# frozen_string_literal: true

source "https://rubygems.org"

# 🌱 Core Rails stack
gem "rails", "~> 8.0.2"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"
gem "bcrypt", "~> 3.1", ">= 3.1.20"
gem "bootsnap", require: false
gem "tzinfo-data", platforms: %i[windows jruby]
gem "rack-cors", require: "rack/cors"

# 🧠 Background Jobs & Caching
gem "sidekiq", "~> 8.0"
gem "redis", "~> 5.4"
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# 🔐 Auth, Authorization, Environment
gem "jwt", "~> 3.1"
gem "pundit", "~> 2.5"
gem "dotenv-rails", "~> 3.1"

# 🗃️ Serializers, Search, Pagination
gem "active_model_serializers", "~> 0.10.15"
gem "ransack", "~> 4.3"
gem "pagy", "~> 9.3"

# 🖼️ File & Image uploads
gem "aws-sdk-s3", "~> 1.183"
gem "image_processing", "~> 1.14"

# 🧰 Utilities
gem "annotate", "~> 2.6"
gem "discard", "~> 1.4"
gem "uuidtools", "~> 3.0"

# 🚀 Production tools (optional)
gem "kamal", require: false
gem "thruster", require: false

group :development, :test do
  # 🧪 Testing
  gem "factory_bot_rails", "~> 6.4", ">= 6.4.4"
  gem "faker", "~> 3.5", ">= 3.5.1"
  gem "rspec-rails", "~> 7.1", ">= 7.1.1"
  gem "rswag", "~> 2.16"
  gem "rswag-ui", "~> 2.16"
  gem "rswag-api", "~> 2.16"

  # 🐞 Debugging & Static analysis
  gem "brakeman", require: false
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "rubocop-rails-omakase", require: false
end

group :test do
  gem "database_cleaner-active_record"
  gem "shoulda-matchers"
end

gem "mobility", "~> 1.3"
