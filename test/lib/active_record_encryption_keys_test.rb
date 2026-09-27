require "test_helper"

class ActiveRecordEncryptionKeysTest < ActiveSupport::TestCase
  test "producao sem as chaves no credentials levanta erro claro" do
    Rails.application.credentials.stub :active_record_encryption, nil do
      error = assert_raises(RuntimeError) { ActiveRecordEncryptionKeys.configure_from_credentials! }
      assert_match "active_record_encryption", error.message
    end
  end

  test "producao com credentials incompleto tambem levanta erro" do
    incompleto = { primary_key: "abc" }.with_indifferent_access

    Rails.application.credentials.stub :active_record_encryption, incompleto do
      error = assert_raises(RuntimeError) { ActiveRecordEncryptionKeys.configure_from_credentials! }
      assert_match "deterministic_key", error.message
      assert_match "key_derivation_salt", error.message
    end
  end

  test "producao com chave em formato invalido (nao hex de 64) levanta erro em vez de subir com conteudo errado" do
    valido = SecureRandom.hex(32)
    invalido = {
      primary_key: "z" * 64,
      deterministic_key: valido,
      key_derivation_salt: valido
    }.with_indifferent_access

    Rails.application.credentials.stub :active_record_encryption, invalido do
      error = assert_raises(RuntimeError) { ActiveRecordEncryptionKeys.configure_from_credentials! }
      assert_match "primary_key", error.message
    end
  end
end
