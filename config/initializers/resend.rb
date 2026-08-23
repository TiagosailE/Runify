# API key so a mensagem chega de verdade em producao (RESEND_API_KEY no
# painel do Render). Em dev/test fica em branco -- inofensivo, porque o
# delivery_method so vira :resend em production.rb.
Resend.api_key = ENV["RESEND_API_KEY"]
