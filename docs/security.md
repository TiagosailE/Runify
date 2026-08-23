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

Um ator: o **usuário autenticado**. Não existe papel de administrador nem
painel interno — cada usuário só acessa os próprios dados, sempre a partir
de `current_user`.

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

Dezessete atributos `style="..."` sobrevivem em `home/index.html.erb`,
`onboarding/step1`/`step2`/`step2_view.html.erb` e `pacers/index.html.erb`
— cor de borda, largura de barra e sombra calculadas no servidor a partir
de dados do usuário (`border_color`, `tier_data[:color]`, `bar_pct`), nunca
de texto que o usuário digitou. `script-src` continua travado em `'self'`
sem `unsafe-inline`, que é o vetor de XSS mais perigoso; permitir só
`style-src-attr` limita o que um eventual HTML não escapado conseguiria
fazer a alterar aparência, não executar script.

**Não verificado em navegador nesta rodada** — a ferramenta de automação
usada para testar não conseguiu compor visualmente a página nesta sessão
(problema da ferramenta, não confirmado como relacionado à CSP: mesmo
removendo `frame-ancestors` a composição continuou falhando). Testado por
`curl` que o HTML renderiza os 17 atributos corretamente e que o header
`Content-Security-Policy` sai com `style-src-attr 'unsafe-inline'`; o que
falta é abrir o dashboard e a tela de squads (`/pacers/:id`) num navegador
de verdade e confirmar visualmente que as cores de borda e a barra de km
aparecem. Ver item 5.

### 3.4 Rate limiting

Não havia nenhum. `rate_limit` nativo do Rails 8 (sem gem nova) entrou em:

- Login (`Users::SessionsController`): 10 tentativas / 3 minutos.
- Cadastro (`Users::RegistrationsController`): 5 / hora.
- Recuperação de senha (`Users::PasswordsController`): 5 / 15 minutos.
- Criação/import de atividade (`ActivitiesController`): 20 / hora, por
  usuário (não por IP) — protege contra farm de XP e bloat de banco via
  o formulário de registro manual, não contra força bruta de credencial.

Exigiu gerar os controllers do Devise (`app/controllers/users/`) porque a
gem não expõe ponto de customização sem isso — `devise_for` foi reapontado
em `config/routes.rb`.

### 3.5 Dado pessoal no log

`filter_parameters` cobria e-mail e senha, mas não `weight`, `height`,
`birth_date` — iam inteiros pro log em toda submissão de onboarding/cadastro.

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
2. **`RAILS_MASTER_KEY`**: não está em nenhum `.env` deste ambiente de
   trabalho, e `config/master.key` não existe em disco. Sem ela,
   `config/credentials.yml.enc` (548 bytes, conteúdo desconhecido nesta
   sessão) não decripta e o app não tem `secret_key_base` estável em
   produção — os tokens do Strava já criptografados também dependem dessa
   chave para continuar legíveis. Precisa ser resolvido antes do deploy:
   ou o Tiago tem a chave original guardada em algum lugar, ou
   `bin/rails credentials:edit` gera um par novo (e qualquer credencial já
   guardada no arquivo antigo se perde).
3. **Verificação visual da CSP** — ver item 3.3. Abrir `/dashboard` e
   `/pacers/:id` autenticado, confirmar que cores de borda/sombra de tier e
   a barra de km aparecem, e olhar o console do navegador por qualquer
   violação de CSP que a verificação por `curl` não conseguiria pegar.
4. **`APP_HOST`** com o domínio real do Render, quando existir, pra ligar
   `config.hosts`.
5. **GitHub**: 2FA na conta e *secret scanning* — o repo é privado hoje,
   mas nada impede tornar público depois (como o Rota Velho Chico), e vale
   ligar antes independente disso.
