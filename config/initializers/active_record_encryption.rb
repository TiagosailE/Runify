secret = Rails.application.secret_key_base
key_generator = ActiveSupport::KeyGenerator.new(secret, iterations: 1000)

Rails.application.config.active_record.encryption.primary_key = key_generator.generate_key("active_record_encryption_primary_key", 32)
Rails.application.config.active_record.encryption.deterministic_key = key_generator.generate_key("active_record_encryption_deterministic_key", 32)
Rails.application.config.active_record.encryption.key_derivation_salt = key_generator.generate_key("active_record_encryption_key_derivation_salt", 32)
