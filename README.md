# Runify

Runify é uma aplicação Rails para corredores amadores que combina onboarding esportivo, integração com o Strava, geração de planos com Gemini e recursos sociais como pacers, notificações e XP.

## Funcionalidades

- Onboarding com dados físicos, experiência de corrida e objetivo do atleta
- Autenticação com Devise
- Conexão com Strava via OAuth e sincronização de atividades
- Geração de training plans com Gemini
- Feedback de treinos e ajuste do plano
- Histórico de atividades e dashboard do corredor
- Pacers/Squads com ranking de membros
- Notificações de treino, sincronização e resumo semanal
- Sistema de XP, nível e conquistas

## Stack

- Ruby on Rails 8.1.1
- PostgreSQL
- Turbo + Stimulus
- Tailwind CSS
- Devise
- `strava-ruby-client`
- `gemini-ai`
- Solid Cache, Solid Queue e Solid Cable

## Pré-requisitos

- Ruby 3.x
- Bundler
- PostgreSQL
- Arquivo `.env` na raiz do projeto

## Variáveis de ambiente

Crie um `.env` com as chaves necessárias para desenvolvimento local:

```env
GEMINI_API_KEY=sua_chave_gemini
STRAVA_CLIENT_ID=seu_client_id
STRAVA_CLIENT_SECRET=seu_client_secret
POSTGRES_PASSWORD=sua_senha_postgres
RUNIFY_DATABASE_PASSWORD=sua_senha_postgres
```

## Setup inicial

```bash
bin/setup
```

Para preparar o ambiente sem subir o servidor:

```bash
bin/setup --skip-server
```

## Comandos principais

### Desenvolvimento

```bash
bin/dev
bin/rails server
bin/jobs
```

- `bin/dev` inicia o servidor Rails e o watcher do Tailwind
- `bin/rails server` sobe apenas o servidor Rails
- `bin/jobs` inicia o worker de jobs

A aplicação roda em `http://localhost:3000`.

### Banco de dados

```bash
bin/rails db:prepare
bin/rails db:seed
```

### Testes e validação

```bash
bin/rails test
bin/rails test:system
bin/rubocop
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
bin/bundler-audit
bin/importmap audit
bin/ci
```

## Arquitetura em alto nível

Runify é um monólito Rails 8.1 com views server-rendered.

### Modelos centrais

- `User`: perfil do atleta, autenticação, notificações, squads e conexão com Strava
- `Activity`: atividades sincronizadas do Strava
- `TrainingPlan` e `Workout`: plano de treino e sessões programadas
- `Squad` e `SquadMember`: grupo social, ranking e XP
- `Achievement` e `UserAchievement`: conquistas do usuário
- `Notification`: notificações internas da aplicação

### Fluxo do Strava

`StravaController` recebe o OAuth callback, persiste a integração via `StravaIntegration` e dispara a sincronização de atividades.

### Fluxo de IA

`AiTrainingService` monta o prompt com dados do usuário e atividades recentes, chama o Gemini e cria `TrainingPlan` + `Workout`.

`AiAdjustmentService` analisa feedbacks e ajusta treinos futuros quando há dados suficientes.

## Rotas principais

- `/dashboard`
- `/profile`
- `/training`
- `/history`
- `/notifications`
- `/pacers`
- `/settings`
- `/onboarding/step1`
- `/strava/connect`

## Observação conhecida

`config/schedule.rb` referencia `SyncReminderJob`, mas essa classe não existe hoje no repositório.
