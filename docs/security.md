# Segurança

O que o Runify protege, de quem, e as decisões tomadas para isso.
Complementa [`architecture.md`](architecture.md) (que descreve o domínio) e o
README (que resume as decisões de engenharia).

---

## 1. O que há para proteger

| Ativo | Por que importa |
|---|---|
| Dados pessoais e biométricos | E-mail, peso, altura, data de nascimento coletados no onboarding. Base direta da coleta de dados do TG. |
| Conexão Strava (quando existir) | `access_token`/`refresh_token` dão acesso à conta Strava real do usuário fora do Runify. |
| Sessão do usuário | Autenticação via Devise; sequestro de sessão expõe todo o histórico de treino e dados pessoais. |
| Disponibilidade da conta | Um usuário só tem uma conta; login/cadastro/recuperação de senha são alvo natural de força bruta. |

Dois atores:

- **O usuário autenticado** — acessa só os próprios dados, sempre a partir de
  `current_user`. É o caso de todas as telas do app.
- **O administrador** (`users.admin = true`, introduzido em 2026-09-04) —
  acessa o painel de suporte em `/admin`, que lê dado operacional de qualquer
  usuário e executa três ações de escrita sobre a conta deles. Ver seção 7.

Até 2026-09-04 havia um ator só; o painel foi adicionado porque os testes com
usuários reais do TG precisam de um caminho de suporte que não seja abrir
console de produção. A ampliação é deliberada e vem com limite de escopo
explícito — o painel **não** lê peso, altura, data de nascimento nem histórico
de lesão.

## 2. Controles que já vinham do desenho

- **CSRF** ligado por padrão do Rails em todo formulário.
- **Tokens do Strava criptografados** (`encrypts`, Active Record Encryption)
  em vez de texto puro no banco — ver `app/models/strava_integration.rb`.
- **CI barra regressão**: `bin/ci` roda Brakeman, `bundler-audit` e
  `importmap audit` a cada execução.

## 3. O que esta rodada fechou (2026-08-23)

### 3.1 HTTPS obrigatório

`config.force_ssl` e `config.assume_ssl` estavam comentados em produção. Sem
eles não há HSTS, não há redirecionamento HTTP→HTTPS, e o cookie de sessão
não é marcado `secure`. Ligados os dois juntos — o deploy planejado (Render)
termina TLS na borda e encaminha por HTTP internamente, então o app precisa
assumir que a conexão já chegou segura. `/up` (health check) fica fora do
redirecionamento.

**Contrapartida:** se o Runify algum dia rodar via Kamal numa VPS sem proxy
de TLS na frente (documentado como caminho alternativo, não usado hoje),
`assume_ssl` faria o cookie de sessão sair marcado `secure` mesmo servindo
HTTP puro — o navegador descarta esse cookie e o login falha em silêncio.
Não é um problema hoje porque o caminho de deploy real é o Render.

### 3.2 Content Security Policy

Não havia nenhuma — o initializer estava inteiro comentado. Construída a
partir do que o app carrega de verdade:

- `script-src 'self'` com nonce por sessão (importmap, os dois scripts
  inline do layout).
- `style-src 'self' https://cdnjs.cloudflare.com https://fonts.googleapis.com`
  (Font Awesome + Google Fonts, os dois `@import`/`<link>` externos reais do
  app) com nonce para os cinco blocos `<style>` que sobreviveram.
- `img-src 'self' https: data:` — o app tem duas origens externas de imagem
  hoje (`ui-avatars.com` como fallback de avatar, `images.unsplash.com` no
  hero da landing) e potencialmente mais no futuro (fotos do Strava); fixar
  host por host seria frágil e `script-src` já bloqueia o vetor mais perigoso.
- `frame-ancestors 'none'`, `object-src 'none'`.

**Achados só na verificação, não no design inicial** — a CSP expôs padrões
que já quebravam a política assim que ligada:

- **`toast.js`** usava `.style.cssText`, `.style.animation` e injetava um
  `<style>` via JS pros `@keyframes` — as três formas de estilo dinâmico que
  a CSP bloqueia. Refeito: posicionamento e animação viraram classes CSS
  (`.toast-notification`, `.toast-closing`, seletores `:nth-child` pro
  empilhamento), os `@keyframes` foram pro `app/assets/stylesheets/application.css`
  estático. Zero comportamento visual mudou.
- **Dez atributos `onclick=`/`onchange=` inline** espalhados em
  `training/index`, `profile/index`, `settings/index`, `history/index` e
  `pacers/show` — todos convertidos para `addEventListener` dentro dos
  blocos `turbo:load` já existentes em `training.js`, `profile.js` e
  `settings.js`. As funções (`showLogoutModal`, `confirmCompleteWorkout`
  etc.) continuam as mesmas; só a forma de disparar mudou.
- **Um `<script>` cru sem nonce** em `profile/index.html.erb`
  (`previewAvatar`) — função movida para `profile.js`, disparada por
  `addEventListener` no input de avatar.
- **Dois `style="backdrop-filter: blur(4px)"`** em `training/index` e
  `profile/index` eram redundantes com a classe Tailwind `backdrop-blur-sm`
  já presente nos mesmos elementos — removidos sem substituto, porque a
  classe já fazia o mesmo efeito.

### 3.3 `style-src-attr 'unsafe-inline'` — aceito conscientemente

Reduzido na reforma do módulo Pacers (2026-08-23): `pacers/index.html.erb`
caiu de ~10 atributos `style="..."` para 1, `pacers/show.html.erb` de ~4
para 1 — cor de borda, box-shadow e background por tier saíram de string
Ruby montada à mão (`SquadMember#tier_data`/`#border_style`, o segundo
removido por não ter uso) para classes CSS estáticas em
`components/pacer_frames.css` (`.tier-<border_tier> .avatar-ring` etc.),
carregadas via `<link>` de verdade, não `<style nonce>` inline.

18 atributos `style="..."` sobrevivem no total (contagem por ocorrência),
em `home/index.html.erb` (12), `onboarding/step1`/`step2`/
`step2_view.html.erb` (1 cada), `training/index.html.erb` (1),
`pacers/index.html.erb` (1) e `pacers/show.html.erb` (1) — cor de borda,
largura de barra e sombra calculadas no servidor a partir de dados do
usuário (`border_color`, `bar_pct`), nunca de texto que o usuário digitou.
`script-src` continua travado em `'self'` sem `unsafe-inline`, que é o
vetor de XSS mais perigoso; permitir só `style-src-attr` limita o que um
eventual HTML não escapado conseguiria fazer a alterar aparência, não
executar script.

**Não verificado em navegador nesta rodada, de novo** — o painel de
navegador da automação continuou sem compor a página visualmente (mesmo
sintoma registrado em `NOTES.md` desde 2026-08-23: tab reaberta, mesmo
erro). Verificado por `curl` autenticado: HTML de `/pacers` e `/pacers/:id`
renderiza as classes `tier-*`/`avatar-ring`/`level-badge` corretas, a nova
stylesheet `components/pacer_frames.css` é servida via `<link>` (confirma
que o glob `stylesheet_link_tag :app` do Propshaft pega qualquer `.css`
novo em `app/assets/**` automaticamente, sem registro manual), o ícone de
tier do membro aparece corrigido (testado subindo o nível do usuário demo
pra 65 temporariamente, revertido depois) e nenhuma classe morta
(`tier-challenger`/`grandmaster`/`master`) sobrou no CSS gerado. O que
falta é abrir `/pacers` e `/pacers/:id` num navegador de verdade e
confirmar visualmente que o brilho e o pulso das tiers ficaram bons — Tiago
não deu esse retorno ainda.

### 3.4 Rate limiting

Não havia nenhum. `rate_limit` nativo do Rails 8 (sem gem nova) entrou em:

- Login (`Users::SessionsController`): 10 tentativas / 3 minutos.
- Cadastro (`Users::RegistrationsController`): 5 / hora.
- Recuperação de senha (`Users::PasswordsController`): 5 / 15 minutos.
- Criação de atividade (`ActivitiesController`): 20 / hora, por usuário
  (não por IP) — protege contra farm de XP e bloat de banco via o
  formulário de registro manual, não contra força bruta de credencial.

Exigiu gerar os controllers do Devise (`app/controllers/users/`) porque a
gem não expõe ponto de customização sem isso — `devise_for` foi reapontado
em `config/routes.rb`.

### 3.5 Dado pessoal no log

`filter_parameters` cobria e-mail e senha, mas não `weight`, `height`,
`birth_date` — iam inteiros pro log em toda submissão de onboarding/cadastro.

**Complemento em 2026-09-04:** `injury_history` também estava de fora, apesar
de ser o dado mais sensível do app (saúde, Art. 11 da LGPD). Adicionado à
lista.

### 3.6 Senha de demonstração fixa no repositório

`db/seeds.rb` tinha `password123` escrito no arquivo. Como o app vai ao ar
com o mesmo seed rodando em produção (dados de demonstração para o TG), a
senha virou obrigatória via `SEED_USER_PASSWORD` fora de dev/test — ausente,
o seed para com erro em vez de cair num padrão adivinhável. Em dev/test o
padrão `password123` continua valendo (banco local, sem valor pra ninguém,
e o passo `Tests: Seeds` do `bin/ci` depende dele).

## 4. Aceito conscientemente

- **`img-src` aceita qualquer `https:`** — ver item 3.2.
- **`style-src-attr 'unsafe-inline'`** — ver item 3.3.
- **Sem `:lockable` no Devise.** Bloquear conta por tentativas erradas abre
  um jeito trivial de negar acesso ao usuário legítimo. O rate limit por
  IP (login) cobre a varredura de senha sem esse efeito colateral — mesmo
  raciocínio já usado no Rota Velho Chico.
- **`config.hosts` continua comentado.** Ativa proteção contra Host header
  forjado, mas exige o domínio real de produção, que ainda não existe (a
  entrega `chore/production-config` ainda não rodou). Ligar sem o valor
  certo derruba o app inteiro em vez de proteger algo.

## 5. Fora do repositório

1. **`SEED_USER_PASSWORD`** precisa existir no ambiente publicado antes do
   primeiro `db:seed` em produção.
2. **`RAILS_MASTER_KEY`** — resolvido na entrega `chore/production-config`:
   confirmado que `config/credentials.yml.enc` nunca tinha sido editado
   desde o commit inicial (só o stub padrão do Rails), então o Tiago gerou
   um par novo sem perder nada de valor. O conteúdo de `config/master.key`
   (gitignorado, só em disco local) precisa ir na env var
   `RAILS_MASTER_KEY` do painel do Render antes do primeiro deploy.
3. **Verificação visual da CSP** — ver item 3.3. Abrir `/dashboard` e
   `/pacers/:id` autenticado, confirmar que cores de borda/sombra de tier e
   a barra de km aparecem, e olhar o console do navegador por qualquer
   violação de CSP que a verificação por `curl` não conseguiria pegar.
4. **`APP_HOST`** com o domínio real do Render, quando existir, pra ligar
   `config.hosts`.
5. **GitHub**: 2FA na conta e *secret scanning* — o repo é privado hoje,
   mas nada impede tornar público depois (como o Rota Velho Chico), e vale
   ligar antes independente disso.
6. **`SENTRY_DSN`** — precisa de conta na Sentry (não posso criar contas) e
   o DSN do projeto colado no painel do Render antes do primeiro deploy com
   monitoramento ativo. Sem essa env var o SDK fica inativo (ver item 6
   abaixo) — não derruba a app, só não reporta nada.

## 6. Monitoramento de erro (2026-08-24)

Não existia nenhum — um erro 500 em produção só aparecia se alguém abrisse
o log do Render manualmente ou um usuário reportasse. Com testes reais
começando sem o Tiago olhando a tela o tempo todo, isso significava bug
rodando batido por dias sem ninguém saber.

`sentry-ruby` + `sentry-rails` adicionados, `config/initializers/sentry.rb`
lê `SENTRY_DSN` do ambiente. `enabled_environments: %w[production]` — em
dev/test o SDK não inicializa de verdade, então nenhum erro de
desenvolvimento local vaza pra conta da Sentry. `traces_sample_rate: 0.0`
(sem tracing de performance) — o volume de usuário deste TG não justifica
gastar a cota gratuita da Sentry com isso, só error tracking importa aqui.

## 7. Painel administrativo (2026-09-04)

Um segundo ator, adicionado porque suporte a participante real durante os
testes do TG não pode depender de console de produção.

### 7.1 Como alguém vira administrador

Coluna booleana `users.admin`, `default: false, null: false`. Não há gem de
autorização: existe um papel só e um administrador previsto, então `Pundit`
seria peso morto. A checagem é um `before_action` em
`Admin::BaseController` (`current_user&.admin?`); quem não passa é
redirecionado ao dashboard com toast, nunca vê conteúdo do painel.

**Não existe tela que promova alguém a administrador.** O acesso é concedido
só por rake:

```
bin/rails "admin:grant[email@exemplo.com]"
bin/rails "admin:revoke[email@exemplo.com]"
bin/rails admin:list
```

O motivo é concreto: uma tela de promoção transforma qualquer falha de sessão
ou CSRF dentro do painel em escalada de privilégio permanente. `admin` também
não está em nenhum `permit` do Devise nem do `ProfileController`, então não há
caminho de atribuição em massa. No seed, o usuário demo vira admin **fora de
produção** apenas — a senha dele é previsível demais para carregar isso no ar.

### 7.1.1 Como se entra no painel

Dois caminhos, os dois condicionados a `admin?`:

- **Login.** `ApplicationController#after_sign_in_path_for` devolve
  `admin_root_path` quando o usuário é administrador — entrar com a conta de
  suporte já é entrar no modo de suporte. A checagem vem **antes** das de
  onboarding: uma conta administrativa não precisa ter peso e objetivo
  preenchidos, e sem essa ordem ficaria presa no passo 1 sem nunca chegar ao
  painel.
- **Nenhum outro.** Não há link para `/admin` em tela alguma do app, e o
  painel não tem caminho de volta para o app — o único botão do cabeçalho
  encerra a sessão.

### 7.1.2 A conta de administrador é exclusiva do painel

`ApplicationController#confine_admin_to_panel` devolve qualquer requisição de
um usuário `admin?` para `/admin`, exceto: controllers do Devise (sem isso o
administrador não conseguiria sair), o próprio namespace `admin/`, e o
`PagesController` (privacidade/termos/sobre são documentos públicos, não
funcionalidade de corredor).

Na prática: dashboard, treino, Pacers, histórico, perfil, configurações e
onboarding ficam inacessíveis para quem é administrador. A conta não é um
usuário comum com um poder a mais — é uma conta de outro tipo.

Isso tem uma consequência operacional que precisa ser respeitada: **a conta
de administrador não pode ser a mesma que a pessoa usa para correr.**
Conceder `admin` à conta pessoal de alguém tira dessa pessoa o acesso ao app.
Por isso o seed passou a criar `admin@runify.app` separado (fora de produção
apenas) em vez de marcar o usuário demo — o demo precisa continuar sendo um
corredor comum para que as telas do app possam ser testadas.

### 7.2 O que o painel deliberadamente não faz

- **Não exibe peso, altura, data de nascimento nem histórico de lesão.** A
  ficha mostra só se cada campo do onboarding *está preenchido*, nunca o
  valor. Diagnóstico de suporte ("travou no onboarding", "não gera plano",
  "Strava não conecta") não precisa desses dados, e exibir o que não se
  precisa ver é custo puro — de banca, de TCLE e de conversa com participante.
- **Não edita dado do usuário.** Não há formulário de edição no painel.
- **Não exclui conta.** `user.destroy` é destrutivo em cascata: leva junto
  atividades, planos, treinos, notificações, conquistas **e os Pacers que o
  usuário criou, com os membros de outras pessoas dentro** (`user.rb` →
  `owned_squads dependent: :destroy` → `squad.rb` → `squad_members`). Um botão
  de excluir no painel seria uma forma silenciosa de derrubar o grupo de
  terceiros. O caminho de exclusão continua sendo o do próprio titular, em
  Configurações.
- **Não permite entrar como o usuário** (impersonation).

### 7.3 As três ações de escrita

Todas reversíveis, nenhuma destrutiva:

| Ação | O que faz | Por que é segura |
|---|---|---|
| Enviar redefinição de senha | `send_reset_password_instructions` | O e-mail vai pro próprio usuário; o admin nunca vê nem define a senha. Falha de entrega vira aviso na tela, não erro 500. |
| Cancelar plano ativo | `status: "cancelled"` | Não apaga nada; devolve ao usuário a tela de gerar plano novo e preserva o histórico. |
| Desconectar Strava | `destroy` da `StravaIntegration` | Mesmo caminho que o botão "Desconectar" da tela do próprio usuário; ele reconecta sozinho. |

### 7.4 Trilha de auditoria

`admin_audit_logs` (admin, usuário afetado, ação, detalhe, timestamp) — a
primeira tabela de auditoria do projeto. Antes disso nada no sistema
registrava quem fez o quê; com um ator capaz de agir sobre a conta de
terceiros num contexto de pesquisa com TCLE, isso deixou de ser aceitável.

Só ações de **escrita** são registradas. Abrir a ficha de alguém não gera
registro, e isso é coerente com 7.2: o painel não expõe dado pessoal, então
leitura não é um ato que precise de prestação de contas.

As duas chaves estrangeiras usam `on_delete: :cascade`, com
`dependent: :destroy` espelhado no model. Duas razões: a trilha sobre um
usuário some quando ele exerce o direito de eliminação (Art. 18 VI), e a FK
não pode bloquear `SettingsController#delete_account` — o que aconteceria com
`restrict`.

### 7.5 Limites conhecidos

- **Sem paginação.** A listagem devolve todos os usuários; a auditoria, as
  200 mais recentes. Com a meta de até 30 participantes isso não é problema
  hoje, e nenhuma gem de paginação foi adicionada por isso. Se o número
  crescer de verdade, é aqui que se mexe primeiro.
- **Sem `last_sign_in_at`.** O Devise não usa `:trackable` neste projeto, então
  o painel não consegue responder "quando esse usuário entrou pela última
  vez". Ligar `:trackable` é uma migration e uma decisão de privacidade
  própria (passa a registrar IP), deixada para quando houver necessidade real.
- **Sem confirmação de segundo fator para as ações.** O `turbo_confirm` de
  cada botão é proteção contra clique errado, não contra sessão sequestrada.
  Para o escopo de um administrador único num app de 30 usuários, o rate limit
  de login e a sessão do Devise são a defesa; se um dia houver mais de um
  administrador, reconsiderar.
