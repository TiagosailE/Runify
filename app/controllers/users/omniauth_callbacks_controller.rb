# frozen_string_literal: true

class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    auth = request.env["omniauth.auth"]
    user = User.find_by(email: auth.info.email)

    if user
      # E-mail ja verificado pelo Google -- seguro vincular sem senha extra.
      user.update!(provider: auth.provider, uid: auth.uid) if user.provider.blank?
      sign_in_and_redirect user, event: :authentication
      flash[:toast] = { message: "Login com Google realizado com sucesso!", type: "success" }
    else
      # Conta nova via Google ainda precisa passar pelo aceite de termos/
      # privacidade (mesma exigencia do cadastro comum) antes de existir --
      # por isso nao cria o User aqui, so guarda o essencial na sessao.
      session[:google_pending_signup] = {
        "uid" => auth.uid,
        "email" => auth.info.email,
        "name" => auth.info.name
      }
      redirect_to new_google_signup_path
    end
  end

  def failure
    redirect_to new_user_session_path, alert: "Não foi possível autenticar com o Google."
  end
end
