# Paginas institucionais estaticas -- publicas de proposito, sem
# authenticate_user!, porque precisam ser lidas ANTES do cadastro (o
# checkbox de consentimento do formulario linka pra elas).
class PagesController < ApplicationController
  def privacy
  end

  def terms
  end

  def about
  end
end
