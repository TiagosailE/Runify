# Privacidade e LGPD

Como o Runify trata dados pessoais, sob qual base legal, e as decisões
tomadas para isso. Complementa [`security.md`](security.md) (que cobre a
proteção técnica) e [`architecture.md`](architecture.md) (que descreve o
domínio). O texto voltado ao usuário final fica em `/privacidade` e
`/termos` dentro do próprio app — este documento é a justificativa por
trás dele, para a banca/orientador.

---

## 1. Por que isso importa aqui

O Runify não é uma demo de portfólio: vai ao ar com usuários reais a
partir de setembro/outubro de 2026 para coleta de dados do TG, com meta de
até 30 participantes. Isso o coloca sob a LGPD (Lei nº 13.709/2018) de
verdade, não como exercício teórico — e coleta um dado potencialmente
sensível (histórico de lesões, Art. 5º, II).

## 2. Base legal por categoria de dado

| Dado | Base legal | Por quê |
|---|---|---|
| Cadastro (e-mail, senha, username) | Execução de contrato (Art. 7º, V) | Necessário para a conta existir. |
| Perfil físico (peso, altura, idade, experiência) | Execução de contrato (Art. 7º, V) | Necessário para gerar o plano de treino, a função central do app. |
| Histórico de lesões | Consentimento explícito (Art. 7º, I + Art. 11) | Dado sensível de saúde — exige base própria, não cabe em "execução de contrato". |
| Atividades (manual/Strava) | Execução de contrato (Art. 7º, V) | O usuário fornece deliberadamente para acompanhar progresso. |
| Uso agregado para o TG | Legítimo interesse acadêmico, sempre anonimizado | Não identifica o titular individualmente. |

## 3. Consentimento — implementação

Checkbox único no cadastro (`devise/registrations/new.html.erb`), não
granular por finalidade — decisão tomada via `/grilling` com o Tiago:
granularizar por fornecedor (IA vs. Strava vs. armazenamento) adicionaria
complexidade de UX sem ganho real de proteção para um app cujo núcleo
depende de todos eles. O texto da política de privacidade é onde os fluxos
específicos (Gemini, R2, Strava, Resend) ficam explícitos.

Armazenado como `User#terms_accepted_at` (timestamp), não um boolean — é a
evidência que importaria se algum dia fosse preciso provar consentimento,
não apenas um "sim/não" sem data.

**Bug real encontrado na verificação ao vivo, não pelos testes
automatizados na primeira tentativa**: `ActiveModel::Validations::AcceptanceValidator`
do Rails tem `allow_nil: true` **por padrão** — a checagem de aceite só
roda se o campo não for `nil`. Sem `allow_nil: false` explícito, um POST
que omite o parâmetro `terms_accepted` inteiramente (não manda nem "0" nem
"1") passa pela validação sem nenhum consentimento registrado. O
formulário real do Rails (`f.check_box`) sempre manda "0" via campo hidden
quando desmarcado, então esse caminho específico não aparecia testando só
pelo navegador — mas um POST direto (curl, form adulterado, ou qualquer
cliente que não seja o form padrão) conseguiria criar conta sem aceite
algum. Corrigido com `allow_nil: false, allow_blank: false` explícitos.
Teste de regressão em `test/integration/registration_consent_test.rb`
cobre exatamente esse caso (parâmetro ausente, não só "0").

**Contas anteriores ao checkbox** (todas de teste/demo, pré-lançamento):
`terms_accepted_at` foi preenchido retroativamente com `created_at` na
migration — não há como coletar aceite retroativo de verdade, e não existe
usuário real ainda para quem isso importe.

## 4. Terceiros e transferência internacional

Nenhum servidor desses fornecedores fica no Brasil — a política de
privacidade cita isso explicitamente (Art. 33 trata de transferência
internacional):

| Fornecedor | Recebe | Para quê |
|---|---|---|
| Google (Gemini API) | Perfil físico, objetivo, histórico de lesões, atividades recentes | Gerar o plano de treino — é o único que recebe o dado sensível de saúde |
| Strava | Token OAuth, leitura de atividades | Integração opcional (ver `NOTES.md` sobre o app estar `Inactive` do lado deles) |
| Cloudflare (R2) | Foto de perfil | Armazenamento de avatar |
| Resend | E-mail | E-mails transacionais (recuperação de senha) |
| Render | Tudo (infraestrutura) | Hospedagem da aplicação e do banco |

## 5. Direitos do titular (Art. 18) — implementação

| Direito | Onde |
|---|---|
| Acesso | Perfil visível no app; `SettingsController#export_data` para cópia completa |
| Correção | Editar perfil |
| Portabilidade | `SettingsController#export_data` — JSON, exclui `encrypted_password`/`reset_password_token`/tokens do Strava de propósito (segredo operacional, não "dado sobre o titular") |
| Eliminação | `SettingsController#delete_account` — já existia antes desta entrega, `current_user.destroy` de verdade, não soft-delete |
| Revogação de consentimento | Excluir a conta (o núcleo do app depende da IA, então não há um "desligar IA e continuar usando" que faça sentido de produto) |

## 6. Decisões `[E]` do Tiago sobre os gaps encontrados (2026-08-24)

- **Comitê de Ética (CEP) / Plataforma Brasil**: já submetido pelo Tiago
  antes desta sessão. Decisão dele: seguir como se já tivesse sido aceito,
  dado o prazo curto até setembro/outubro. Não é algo que este projeto
  rastreia ou verifica em código — decisão institucional, registrada aqui
  só para constar que foi perguntado e respondido.
- **Idade mínima**: restrita a **18 anos** por decisão explícita do Tiago —
  "o projeto é para maiores de 18 anos, porém posteriormente vou deixar
  aberto para menores idades". Implementado (`User` valida `age >= 18`,
  antes era 12) com o piso antigo comentado no código como temporário.
  Quando ele quiser reabrir para menores, vai precisar implementar o fluxo
  de consentimento parental (LGPD Art. 14) antes de só baixar o número de
  volta — abrir a idade sem esse fluxo reintroduziria o gap original.

## 6.1 Acesso administrativo (2026-09-04)

Até esta data o app tinha um ator só: cada usuário via apenas os próprios
dados. O painel de suporte em `/admin` cria um segundo — necessário porque
os testes com participantes reais precisam de um caminho de correção que não
seja abrir console de produção às 22h.

O escopo do acesso foi limitado de propósito, e o limite é o que torna a
mudança defensável perante o TCLE:

- **O painel não exibe dado pessoal sensível.** Peso, altura, data de
  nascimento e `injury_history` **não aparecem em tela nenhuma do painel**. A
  ficha do usuário mostra apenas se cada campo do onboarding está preenchido
  (✓/✗), nunca o valor. Isso mantém o `injury_history` — o único dado do Art.
  11 coletado pelo app — acessível somente ao próprio titular e ao Gemini
  (§4), como já estava documentado.
- **O que o administrador vê** é dado operacional: e-mail, nome de usuário,
  data de cadastro, `terms_accepted_at`, se há plano de treino ativo e em que
  semana, contagem de treinos por status, contagem de atividades e sua origem,
  estado da conexão Strava, Pacers de que participa, notificações não lidas.
- **O que o administrador pode fazer**: enviar e-mail de redefinição de senha,
  cancelar o plano de treino ativo e desconectar o Strava. Nada mais. Não há
  edição de dados, não há exclusão de conta pelo painel e não há acesso à
  conta do usuário (impersonation).
- **Toda ação de escrita é registrada** em `admin_audit_logs` (quem, sobre
  quem, o quê, quando), consultável em `/admin/audit_logs`. Leitura de ficha
  não gera registro, coerente com o painel não expor dado pessoal.
- **A trilha some com o titular**: as FKs usam `on_delete: :cascade`, então
  exercer o direito de eliminação (§5) apaga também os registros de auditoria
  sobre aquela pessoa.
- **`injury_history` entrou no `filter_parameters`** nesta mesma entrega —
  estava de fora, então ia em claro para o log da aplicação a cada submissão
  de onboarding. Ver `security.md` §3.5.

**Pendente do lado do Tiago:** o texto de `/privacidade` e `/termos` visível
aos usuários, e o TCLE entregue aos participantes, ainda descrevem o app sem
esse segundo ator. Antes dos testes com usuários reais, os dois precisam dizer
que existe acesso administrativo, qual o escopo dele e que ações de suporte
ficam registradas. Isso é redação para revisão dele (e, se for o caso, da
orientadora) — não escrevi o texto público por conta própria.

## 7. Outro gap conhecido

- **Sem versionamento de política**: se o texto de `/privacidade` mudar no
  futuro, não há mecanismo para saber quem aceitou qual versão. Aceitável
  para o escopo de um TCC; se o projeto crescer, `terms_accepted_at` teria
  que virar `terms_version` + `terms_accepted_at`.

## 7. Verificação

`bin/ci` verde (139 testes). Verificado ao vivo contra o servidor de dev:
cadastro sem checkbox → 422 com mensagem clara; cadastro com checkbox →
sucesso, `terms_accepted_at` gravado; `/privacidade`, `/termos`, `/sobre`
acessíveis sem login; `export_data` devolve JSON sem segredos; `settings`
com os três links reais e o botão de download.
