require "test_helper"

class LocaleCompletenessTest < ActiveSupport::TestCase
  PLURAL_KEYS = %i[zero one few many other].freeze

  # Chave que só existe no en.yml do gerador do Rails, nunca usada no app.
  IGNORED_KEYS = %w[hello].freeze

  test "pt-BR tem toda chave que o Rails, o Devise e as gems definem em inglês" do
    I18n.backend.send(:init_translations)
    translations = I18n.backend.send(:translations)

    missing = flatten_keys(translations[:en]) - flatten_keys(translations[:"pt-BR"]) - IGNORED_KEYS

    assert_empty missing, "Chaves sem tradução em pt-BR:\n#{missing.sort.join("\n")}"
  end

  private

  def flatten_keys(hash, prefix = nil)
    hash.flat_map do |key, value|
      full_key = [ prefix, key ].compact.join(".")
      nested = value.is_a?(Hash) && (value.keys - PLURAL_KEYS).any?
      nested ? flatten_keys(value, full_key) : [ full_key ]
    end
  end
end
