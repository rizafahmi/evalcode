status: passed

## What's new in the app

- People can register with an email and password, log in, and log out.
- Logged-out visitors are redirected to the login page when they visit the app.
- Signed-in users get an Alur shell with Pipeline, Contacts, and To-dos navigation.
- Pipeline, Contacts, and To-dos have usable authenticated placeholder pages ready for later milestones.

## What was built

- Added Phoenix-generated account, user, token, auth plug, LiveView auth pages, session controller, fixtures, and SQLite migration.
- Added password-backed registration in `Alur.Accounts.register_user_with_password/1`; product-created accounts are confirmed immediately because this milestone has no mailer flow.
- Added authenticated LiveView routes for `/`, `/contacts`, and `/todos`.
- Replaced the Depot scaffold navigation with the Alur authenticated shell in `lib/alur_web/components/layouts.ex`.
- Added `PipelineLive`, `ContactsLive`, and `TodosLive` placeholder views.
- Updated feature/controller/auth tests and added shell navigation coverage.

## Decisions and deviations

- Used Phoenix's `phx.gen.auth --live` implementation as the auth foundation, then added a product-specific password registration path. The generated magic-link internals remain available for framework compatibility but are not exposed by the milestone registration flow.
- No outbound email is required for registration; accounts are confirmed on creation and users are redirected to password login.
- The original scaffold `PageController` files remain in the repository for now, but `/` is owned by the authenticated `PipelineLive` route.

## Verification

- `mix ecto.migrate` passed.
- `mix test` passed: 113 tests.
- `mix precommit` passed: formatter, tests, Credo, Dialyzer, ExDNA, and Reach.
- HTTP checks passed for logged-out redirects from `/` and `/contacts`, plus login-page password/registration markers.
- The available browser automation bridge could not connect, so no interactive browser session was available in this environment.

## Notes for the next milestone

- Build contact CRUD under the existing authenticated shell and scope all records to the signed-in account.
- Keep the Pipeline and To-dos pages as the navigation targets while replacing only the Contacts placeholder.
