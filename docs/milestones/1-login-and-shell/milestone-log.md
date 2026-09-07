# Milestone 1 — Login and shell

status: passed

## What's new in the app

- You can create an account with your email and a password, and you are signed in right away.
- You can log in with email and password, and log out from the top bar.
- Logged-out visitors only ever see the sign-in and registration pages — the app itself is out of reach.
- After signing in you land on the Pipeline home page with a navigation bar for **Pipeline**, **Contacts**, and **To-dos**, plus your email and a **Log out** button.
- The three sections are placeholder pages for now (Pipeline and To-dos are allowed to be empty placeholders in this milestone; Contacts gets built next).
- Everything is styled with the Depot design system (dark server-console: carbon canvas, hairline borders, green primary CTA, Red Hat type).

## What was built

### Files, models, routes

- **Auth context** — `lib/alur/accounts.ex` (`Alur.Accounts`) with
  - `Account` (`lib/alur/accounts/account.ex`) — table `accounts`: `email`, `hashed_password`, timestamps. Registration changeset validates email format/uniqueness and a 12–72 byte password; passwords hashed with bcrypt.
  - `AccountToken` (`lib/alur/accounts/account_token.ex`) — table `accounts_tokens`: opaque DB session tokens (SHA-256 hashes only, `context: "session"`, 60-day validity).
  - Context functions: `register_account/1`, `change_account_registration/2`, `get_account_by_email/1`, `get_account_by_email_and_password/2`, `generate_account_session_token/1`, `get_account_by_session_token/1`, `delete_account_session_token/1`.
- **Migration** — `priv/repo/migrations/20250101000001_create_account_auth_tables.exs`.
- **Web auth** — `lib/alur_web/account_auth.ex` (`AlurWeb.AccountAuth`): `log_in_account/2`, `log_out_account/1`, controller plugs `:fetch_current_scope`, `:redirect_if_account_is_authenticated`, `:require_authenticated_account`, and LiveView `on_mount` hooks `:mount_current_scope` / `:require_authenticated`. Signed-in state is a DB session token stored in the plug session — the same cookie session later milestones' JSON API will reuse.
- **Controllers** — `lib/alur_web/controllers/account_registration_controller.ex` (register → sign in), `account_session_controller.ex` (log in / log out). HTML views under `account_registration_html/` and `account_session_html/` (`new.html.heex` templates, `<Layouts.app>` + Depot-styled forms).
- **Routes** (`lib/alur_web/router.ex`):
  - `GET/POST /accounts/register`, `GET/POST /accounts/log-in`, `DELETE /accounts/log-out`.
  - Authenticated `live_session :authenticated` (on_mount `:require_authenticated`) with `live "/" → PipelineLive`, `live "/contacts" → ContactsLive`, `live "/todos" → TodosLive`.
- **Shell** — `lib/alur_web/components/layouts.ex`: `<Layouts.app>` now renders the signed-in top bar (brand, nav, account email, log-out link) and only shows the nav when a `current_scope` (the signed-in account) is present; `flash_group` moved here as before. New `empty_state` component added to `core_components.ex`.
- **Placeholder LiveViews** — `lib/alur_web/live/pipeline_live.ex`, `contacts_live.ex`, `todos_live.ex`.
- **Dependency** — `bcrypt_elixir` added via `mix igniter.add` for password hashing.
- **Removed** — the Phoenix marketing `PageController`/`PageHTML` home and its tests (logged-out visitors must not see a landing page).

### Tests (27 total, all green via `mix test`)

- `test/alur/accounts_test.exs` — registration validation, password hashing/verify, session token lifecycle incl. expiry.
- `test/alur_web/features/register_and_shell_test.exs` — PhoenixTest browser flows: register → signed-in shell → open all three sections → log out → app unreachable.
- `test/alur_web/features/log_in_test.exs` — PhoenixTest: log in, cross-links between log-in/register, wrong-password error.
- `test/alur_web/controllers/auth_flow_test.exs` — ConnTest: logged-out visitors redirected off `/`, `/contacts`, `/todos`; register signs in; log-out flash; invalid log-in error.
- Verified by HTTP against a running dev server (`mix phx.server`): `/` and `/contacts` 302 → `/accounts/log-in`; full register → signed-in pipeline page rendered with nav and welcome flash.

## Decisions and deviations (not in the PRD)

1. **Did not run `mix phx.gen.auth`.** Phoenix 1.8.13's generator (the version locked in this repo) now produces magic-link/email-confirmation authentication: registration collects only an email and logs you in via an emailed link. That directly contradicts the locked decisions ("email/password", "no outbound mailer", "no password-reset email in v1") and the milestone's "register with email and password". Per the ambiguity rule I implemented the classic Phoenix email+password auth flow the decisions describe (Phoenix 1.7 `phx.gen.auth` shape), trimmed to v1: register with password, log in with password, DB session tokens, no confirmation/reset emails, no settings pages.
2. **Entity named `Account`** (not `User`) to match the PRD data model; context `Alur.Accounts`, table `accounts`. Milestone 2+ records belong to it.
3. **`current_scope` convention**: authenticated LiveViews and controller pages receive `current_scope` — the signed-in `%Alur.Accounts.Account{}` or `nil`. `<Layouts.app>` is always called with it. (Matches the repo's AGENTS.md guidance and the `Layouts.app` attribute.)
4. **binary_id primary keys** chosen for `accounts`/`accounts_tokens` so they line up with this repo's generator default (`generators: [binary_id: true]`) — later milestones' generated schemas will reference `accounts` with `:binary_id` foreign keys.
5. Password rule is 12–72 characters (bytes for the max), matching Phoenix's auth defaults. No extra complexity rules in v1.
6. Registration signs the account in immediately (no email step). Flash messages are set *before* `log_in_account`/`log_out_account` because the redirect sends the response immediately and would otherwise drop them.
7. Placeholder copy on Pipeline/Contacts/To-dos is explicitly labelled as coming-later so the nav can be exercised now.

## Notes for the next milestone

- Contacts milestone: build the contacts CRUD inside the existing `live_session :authenticated`; every page starts `<Layouts.app flash={@flash} current_scope={@current_scope}>`. `current_scope` *is* the account record (`@current_scope.id`, `.email`).
- New resources referencing accounts use `@foreign_key_type :binary_id` and `references(:accounts, type: :binary_id, on_delete: :delete_all)`.
- When a contact is shown only for its owner, filter by `account_id` from `@current_scope.id`.
- Re-run `mix phx.gen.auth` is not needed; account plumbing (register/log-in/session) is complete for the whole app.
- PhoenixTest feature files live in `test/alur_web/features/`; `mix test` runs migrations automatically.
- **SQLite gotcha:** any test module that writes to the DB must use `async: false` — concurrent async tests against the shared `alur_test.db` file intermittently fail with `Exqlite.Error: Database busy`. The scaffold's DB-free tests stay `async: true`.
- Gate used: `mix format --check-formatted`, `mix credo --strict`, full `mix test` — all clean/green.
- No commit was made by this worker (the parent orchestrator commits each green milestone per `docs/run-autonomous.md`).
