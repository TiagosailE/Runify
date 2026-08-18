# Arquitetura

Fluxos e contratos dos service objects do Runify. Para o schema do banco,
tabela por tabela, ver [`modelagem-banco-de-dados.md`](modelagem-banco-de-dados.md).

Monólito Rails 8.1, views server-rendered (Turbo + Stimulus + Tailwind, sem
Node/SPA). Três atores: o visitante anônimo (onboarding, landing), o
usuário autenticado (Devise) e os jobs em background (Solid Queue).

## Fonte de dados de atividade

Duas origens alimentam `Activity`, e o design assume desde o início que uma
atividade pode vir de qualquer uma delas — o campo `activity_data` (JSONB)
guarda o payload bruto independente da origem, e os campos normalizados
(`distance`, `duration`, `sport_type` etc.) são o contrato comum:

- **Strava** (opcional, best-effort) — descrito abaixo.
- **Manual / import GPX-TCX** — fonte principal para a coleta de dados do
  TG, já que a conta de desenvolvedor do Strava tem capacidade de só 1
  atleta simultâneo no nível gratuito (ver `PROGRESS.md`).

## Fluxo Strava

```
StravaController#connect
  → gera state (SecureRandom), guarda em session junto com o user_id
  → redireciona pro Strava (approval_prompt: force)

StravaController#callback
  → valida state contra a sessão (secure_compare) -- sem isso, rejeita
  → troca code por token via Strava::OAuth::Client
  → StravaIntegration.find_by(strava_athlete_id:) -- índice único no banco
    → se pertence a outro user_id: bloqueia, mostra erro
  → destrói a integração anterior do user (se houver) e cria a nova
  → SyncStravaActivitiesJob.new.sync_user_activities(user) -- síncrono,
    não lança exceção, resultado só vira log se falhar
  → sempre mostra "conectado com sucesso" se chegou até aqui
```

`StravaIntegration` guarda `access_token`/`refresh_token` criptografados
(`encrypts`, Active Record Encryption) e sabe se renovar sozinha
(`ensure_valid_token!` → `refresh_token!` quando falta menos de 1 minuto
pro `token_expires_at`).

`SyncStravaActivitiesJob#sync_user_activities(user)` é o único lugar que
fala com `athlete_activities` da API — a action `sync` (botão manual) e o
callback de conexão chamam o mesmo método diretamente (`Job.new.metodo`),
não `perform_later`, porque em dev nada roda a fila sem `bin/jobs` junto do
`bin/dev`. `perform_later` só é usado no `perform` do próprio job, para o
caso de sincronização em lote de todas as integrações ativas — que hoje não
está agendado em lugar nenhum (nem `config/schedule.rb`, nem rake task).

## Fluxo de IA (geração e ajuste de plano)

`AiTrainingService.new(user).generate_training_plan`:
1. Monta prompt com perfil do usuário + até 10 atividades recentes
   (`distance_km`, `duration_formatted`, `pace_per_km`).
2. Chama a API do Gemini (`gemini-2.5-flash`) via `Net::HTTP` direto — não
   usa a gem `gemini-ai` do Gemfile para essa chamada especificamente.
3. Faz parse da resposta e cria `TrainingPlan` + `Workout` em lote.
4. Relança qualquer erro depois de logar (quem chama decide o que mostrar).

`AiAdjustmentService.new(user, training_plan).analyze_and_adjust`:
- Só age a partir da semana 2 do plano (`current_week > 1`), e só se houver
  `Workout` completados na semana anterior — sem dado, sem ajuste.
- Modelo diferente do de geração (`gemini-2.0-flash-exp`).
- Engole a própria exceção (loga e retorna) — ajuste é best-effort, nunca
  deve derrubar o fluxo que o chamou.

## XP e gamificação

`XpService` é uma classe de métodos de classe, sem estado. `award_xp(user,
activity)` roda para cada `squad_member` do usuário, em cada squad ativo:
XP base por km + bônus de pace + bônus de streak (`streak * 10`). Chamado
hoje só a partir do fluxo de sync do Strava (`XpService.award_xp` dentro de
`SyncStravaActivitiesJob`) — a entrada de atividade manual (`PR
feat/manual-activity-entry`) precisa chamar o mesmo método, não duplicar a
lógica de XP.

## Notificações

`NotificationService` são métodos de classe que criam `Notification`
(`send_workout_reminder`, `send_sync_reminder`, `send_congratulations`,
etc.), todos com `return unless user.notifications_enabled?` na entrada.
Disparados pelos jobs agendados em `config/schedule.rb`
(`WorkoutReminderJob`, `DailyNotificationsJob`, `WeeklySummaryJob`) — os
três existem e batem com o que o schedule referencia; a nota antiga no
README sobre um `SyncReminderJob` inexistente estava desatualizada e foi
removida.
