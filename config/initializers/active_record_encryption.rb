# Em producao as chaves ficam fixas no credentials (mesmos valores que a app
# ja usa hoje, derivados do secret_key_base antigo) para nao invalidar dado ja
# cifrado. Dev/test continuam derivando do secret_key_base local -- nao tem
# master key no CI, e nada ali precisa sobreviver a uma troca de chave.
module ActiveRecordEncryptionKeys
  def self.configure!(production: Rails.env.production?)
    production ? configure_from_credentials! : configure_from_secret_key_base!
  end

  def self.configure_from_credentials!
    creds = Rails.application.credentials.active_record_encryption || {}
    missing = %i[primary_key deterministic_key key_derivation_salt].reject { |key| creds[key].present? }
    if missing.any?
      raise "Faltam no credentials as chaves de active_record_encryption: #{missing.join(', ')}"
    end

    Rails.application.config.active_record.encryption.primary_key = [ creds[:primary_key] ].pack("H*")
    Rails.application.config.active_record.encryption.deterministic_key = [ creds[:deterministic_key] ].pack("H*")
    Rails.application.config.active_record.encryption.key_derivation_salt = [ creds[:key_derivation_salt] ].pack("H*")
  end

  def self.configure_from_secret_key_base!
    secret = Rails.application.secret_key_base
    key_generator = ActiveSupport::KeyGenerator.new(secret, iterations: 1000)

    Rails.application.config.active_record.encryption.primary_key = key_generator.generate_key("active_record_encryption_primary_key", 32)
    Rails.application.config.active_record.encryption.deterministic_key = key_generator.generate_key("active_record_encryption_deterministic_key", 32)
    Rails.application.config.active_record.encryption.key_derivation_salt = key_generator.generate_key("active_record_encryption_key_derivation_salt", 32)
  end
end

ActiveRecordEncryptionKeys.configure!
