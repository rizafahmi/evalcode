# Milestone 1 Log — Login and shell

status: passed

## What's new in the app

- **Account Registration & Login**: You can now register a new personal CRM account using your email and password, or log into an existing account.
- **Access Protection**: Logged-out visitors are automatically redirected to the login page and cannot view the protected application views.
- **Signed-in Navigation Chrome**: Once authenticated, the persistent top navigation header appears with links to the three core areas of the app — **Pipeline**, **Contacts**, and **To-dos** — along with your account email and a **Log out** button.
- **Section Placeholders**:
  - **Pipeline (`/`)**: Serving as the home screen, ready for deal stages (`Lead` → `Meeting` → `Proposal` → `Won` → `Lost`).
  - **Contacts (`/contacts`)**: Ready for contact management coming in Milestone 2.
  - **To-dos (`/todos`)**: Ready for follow-up actions and task tracking.
- **Depot Design Aesthetic**: The UI is styled with the Depot dark server-rack design system, featuring a near-black Carbon canvas (`#04040b`), Graphite cards, Basalt hairline borders, tri-tonal typography (Red Hat Display, Text, and Mono), and Signal Green primary action buttons.

## What was built

### Models and Schemas
- `Alur.Accounts.User`: User entity schema with binary ID primary key, lowercase email validation, secure bcrypt password hashing, and confirmation tracking.
- `Alur.Accounts.UserToken`: Session token schema managing authenticated sessions and logout revocation.
- `Alur.Accounts.Scope`: Phoenix 1.8 current_scope struct representing the authenticated context.
- Migration: `priv/repo/migrations/20260906232421_create_users_auth_tables.exs` creating `users` and `users_tokens` SQLite tables.

### Contexts & Auth Logic
- `Alur.Accounts`: Context for registering users (`register_user/1`), authenticating with password (`get_user_by_email_and_password/2`), session token issuance, and sudo mode checks.
- `AlurWeb.UserAuth`: Plugs and LiveView `on_mount` lifecycle hooks (`:require_authenticated`, `:mount_current_scope`, `:require_sudo_mode`) managing session cookies and authentication redirects.

### Views, Controllers & Templates
- `AlurWeb.UserLive.Registration`: LiveView registration form requiring email and password, styled with Depot tokens, automatically logging the user into the session upon creation.
- `AlurWeb.UserLive.Login`: LiveView password authentication screen.
- `AlurWeb.UserSessionController`: Controller handling session creation (`POST /users/log-in`), password updates, and session termination (`DELETE /users/log-out`).
- `AlurWeb.PipelineLive`: Authenticated LiveView for `/` (home).
- `AlurWeb.ContactLive`: Authenticated LiveView placeholder for `/contacts`.
- `AlurWeb.TodoLive`: Authenticated LiveView placeholder for `/todos` and `/to-dos`.
- `AlurWeb.Layouts`: Application chrome layout with the Alur brand, active section tab highlights, user identity display, and logout button.

### Routes
- Authenticated scope (`[:browser, :require_authenticated_user]` inside `live_session :require_authenticated_user`):
  - `GET /` -> `AlurWeb.PipelineLive`
  - `GET /contacts` -> `AlurWeb.ContactLive`
  - `GET /todos` -> `AlurWeb.TodoLive`
  - `GET /to-dos` -> `AlurWeb.TodoLive`
  - `GET /users/settings` -> `AlurWeb.UserLive.Settings`
  - `POST /users/update-password` -> `AlurWeb.UserSessionController, :update_password`
- Public auth scope (`[:browser]` inside `live_session :current_user`):
  - `GET /users/register` -> `AlurWeb.UserLive.Registration`
  - `GET /users/log-in` -> `AlurWeb.UserLive.Login`
  - `POST /users/log-in` -> `AlurWeb.UserSessionController, :create`
  - `DELETE /users/log-out` -> `AlurWeb.UserSessionController, :delete`

### Tests
- Feature test `test/alur_web/features/login_and_shell_test.exs` utilizing `PhoenixTest` to verify:
  - Redirection of logged-out visits to `/users/log-in`.
  - Creating an account with email and password and automatic login.
  - Presence of navigation chrome with Pipeline, Contacts, To-dos, and Log out.
  - Switching between all three sections.
  - Logging out and verifying protected routes are blocked.
  - Logging back in with the created credentials.
- Unit & integration tests for accounts, session controller, liveviews, and layout.

## Decisions not in the PRD

- **Pre-confirmation of accounts**: Since Milestone 1 and v1 have no outbound mailer, accounts are marked as confirmed upon registration so that users can immediately log in and use the application without confirmation friction.
- **Automatic login after registration**: When registering, the registration form sets `phx-trigger-action` on success, submitting to `UserSessionController.create` so users are immediately redirected to `/` (Pipeline) without an extra login step.
- **Route alias for To-dos**: Provided `/to-dos` as an alias alongside `/todos` to avoid any URL kebab-case ambiguity.

## Notes for the next milestone (Milestone 2 — Contacts)

- Milestone 2 will replace the `AlurWeb.ContactLive` placeholder with a full Contacts management page:
  - Schema for `Contact`: `name` (required), `email`, `phone`, `company`, `notes` associated with the current user account (`current_scope.user.id`).
  - Filtering/search by name.
  - Create, edit, detail view, and delete capabilities scoped to the logged-in user.

## Deviations and why

- Removed magic link login/confirmation workflows generated by default in Phoenix 1.8 `phx.gen.auth`, per the explicit requirement in `docs/decisions.md` ("Use phx.gen.auth with email/password and LiveView sessions. No outbound mailer. No password-reset email in v1.") and PRD ("Not in this milestone: OAuth, magic links, 2FA, or email password reset").
