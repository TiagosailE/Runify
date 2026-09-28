# Em producao as chaves ficam fixas no credentials (mesmos valores que a app
# ja usa hoje, derivados do secret_key_base antigo) para nao invalidar dado ja
# cifrado. Dev/test continuam derivando do secret_key_base local -- nao tem
# master key no CI, e nada ali precisa sobreviver a uma troca de chave.
#
# O build da imagem (`SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile`) roda
# em producao sem master key e nunca toca dado cifrado: nele as chaves saem do
# secret_key_base descartavel, senao o build quebra. Essa variavel nunca pode
# estar ligada no runtime.
module ActiveRecordEncryptionKeys
  def self.configure!(production: Rails.env.production?, build: ENV["SECRET_KEY_BASE_DUMMY"].present?)
    production && !build ? configure_from_credentials! : configure_from_secret_key_base!
  end

  HEX_32_BYTES = /\A[0-9a-f]{64}\z/i

  def self.configure_from_credentials!
    creds = Rails.application.credentials.active_record_encryption || {}
    invalid = %i[primary_key deterministic_key key_derivation_salt].reject { |key| creds[key].to_s.match?(HEX_32_BYTES) }
    if invalid.any?
      raise "Chave de active_record_encryption ausente ou não é hex de 64 caracteres no credentials: #{invalid.join(', ')}"
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
