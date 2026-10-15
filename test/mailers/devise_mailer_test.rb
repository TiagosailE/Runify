require "test_helper"

# O "esqueci minha senha" nao sai em producao se o remetente for um dominio que
# a Resend nao verificou. Devise e ApplicationMailer precisam usar o mesmo.
class DeviseMailerTest < ActionMailer::TestCase
  DEFAULT_SENDER = "Runify <onboarding@resend.dev>".freeze

  test "o remetente configurado vem de MAILER_FROM, com padrao que a Resend aceita" do
    assert_equal ENV["MAILER_FROM"].presence || DEFAULT_SENDER, ApplicationMailer.default_params[:from]
    assert_equal ApplicationMailer.default_params[:from], Devise.mailer_sender
  end

  test "e-mail com o codigo de redefinicao de senha sai com o mesmo remetente do ApplicationMailer" do
    mail = UserMailer.password_reset_code(users(:one), "123456")
    expected = Mail::Address.new(ApplicationMailer.default_params[:from])

    assert_equal [ expected.address ], mail.from
    assert_equal [ expected.display_name ], mail[:from].display_names
    assert_no_match(/example\.com/, mail.from.join)
  end
end
