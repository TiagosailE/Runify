# Sem tela de promocao de proposito -- uma falha de sessao no painel viraria
# escalada de privilegio.
#
#   bin/rails "admin:grant[tiago@exemplo.com]"
#   bin/rails "admin:revoke[tiago@exemplo.com]"
#   bin/rails admin:list
module AdminTaskHelpers
  module_function

  def find_user!(email)
    abort "Informe o e-mail: bin/rails \"admin:grant[alguem@exemplo.com]\"" if email.blank?

    User.find_by(email: email.strip.downcase) || abort("Nenhum usuario com o e-mail #{email}.")
  end
end

namespace :admin do
  desc "Concede acesso ao painel administrativo para o e-mail informado"
  task :grant, [ :email ] => :environment do |_task, args|
    user = AdminTaskHelpers.find_user!(args[:email])
    user.update!(admin: true)
    puts "OK: #{user.email} agora tem acesso ao painel administrativo."
  end

  desc "Remove o acesso ao painel administrativo do e-mail informado"
  task :revoke, [ :email ] => :environment do |_task, args|
    user = AdminTaskHelpers.find_user!(args[:email])
    user.update!(admin: false)
    puts "OK: #{user.email} nao tem mais acesso ao painel administrativo."
  end

  desc "Lista quem tem acesso ao painel administrativo"
  task list: :environment do
    admins = User.where(admin: true).order(:email)

    if admins.empty?
      puts "Nenhum administrador cadastrado."
    else
      admins.each { |user| puts "#{user.id}\t#{user.email}" }
    end
  end
end
