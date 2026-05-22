# CLAUDE.md

## Behavioral Guidelines

### 1. Think Before Coding
Don't assume. Don't hide confusion. Surface tradeoffs.

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### 2. Simplicity First
Minimum code that solves the problem. Nothing speculative.

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### 3. Surgical Changes
Touch only what you must. Clean up only your own mess.

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it — don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

### 4. Goal-Driven Execution
Define success criteria. Loop until verified.

Transform tasks into verifiable goals:
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan and wait for approval before executing.

---

## Project: Runify

This file provides guidance to Claude Code when working with this repository.

### Common commands

- `bin/setup` — install gems, prepare the database, clear logs/tmp, and start the dev server.
- `bin/setup --skip-server` — install/update dependencies without starting the app.
- `bin/dev` — run the Rails server plus the Tailwind watcher (Procfile.dev). Port `3000`.
- `bin/rails server` — run only the Rails server.
- `bin/rails db:prepare` — create/migrate the database.
- `bin/jobs` — run the Solid Queue worker.

### Tests

- `bin/rails test` — run the full test suite.
- `bin/rails test test/models/user_test.rb` — run a single test file.
- `bin/rails test test/models/user_test.rb:42` — run a single test by line number.
- `bin/rails test:system` — run system tests.

### Linting and security

- `bin/rubocop`
- `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`
- `bin/bundler-audit`
- `bin/importmap audit`
- `bin/ci` — runs setup, RuboCop, security checks, Rails tests, system tests.

### Required environment

- `.env` file required for local development.
- `GEMINI_API_KEY` — AI plan generation.
- `STRAVA_CLIENT_ID` + `STRAVA_CLIENT_SECRET` — Strava OAuth.
- `POSTGRES_PASSWORD` / `RUNIFY_DATABASE_PASSWORD` — database credentials.

### High-level architecture

Rails 8.1 monolith: runner onboarding, Strava ingestion, AI-generated training plans, social/gamification.

**Core models:**
- `User` — central record, owns profile, Strava connection, activities, plans, squad memberships.
- `Activity` — imported Strava workouts. Normalized fields + raw `activity_data` JSONB.
- `TrainingPlan` + `Workout` — AI-generated plan and scheduled sessions with feedback/adjustment in JSONB.
- `Squad`, `SquadMember`, `Achievement`, `UserAchievement` — pacer/social and XP system.

**Strava flow:** OAuth via `StravaController` → `StravaIntegration` (token storage + refresh) → `SyncStravaActivitiesJob`.

**AI flow:** `AiTrainingService` builds Gemini prompt from profile + 10 recent activities → creates `TrainingPlan` + `Workout` rows. `AiAdjustmentService` mutates future workouts based on feedback.

**Frontend:** Server-rendered Rails views, Turbo, Stimulus, Tailwind via `tailwindcss-rails`. No Node/SPA.

### Known issues

- `config/schedule.rb` referencia `SyncReminderJob`, mas essa classe não existe no repositório.