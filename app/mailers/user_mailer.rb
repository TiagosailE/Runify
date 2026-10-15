class UserMailer < ApplicationMailer
  GOOGLE_RECOVERY_URL = "https://accounts.google.com/signin/recovery".freeze

  def google_account_recovery(user)
    @user = user
    @google_recovery_url = GOOGLE_RECOVERY_URL
    mail(to: user.email, subject: "Como entrar na sua conta Runify")
  end
end
