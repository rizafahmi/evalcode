status: passed

## What's new in the app

- Signed-in users can schedule a follow-up on any deal with a description, due date, and optional time.
- Deal pages show open and completed follow-ups together; open items can be marked done in place.
- The To-dos page lists every open follow-up across the account, soonest due first, with the deal name and a link back to the deal.
- Overdue follow-ups are called out clearly, and completion is available from either the deal or To-dos page.
- Adding and completing a follow-up adds a matching immutable line to the deal activity log.

## What was built

- Added the `next_actions` migration and `Alur.Deals.NextAction` schema, account- and deal-scoped with due timestamp and completion state.
- Extended `Alur.Deals` with account-safe listing, creation, completion, Jakarta due-date formatting, and overdue checks.
- Added activity-log transactions for follow-up creation and completion.
- Extended `DealsLive` with follow-up creation, validation, display, and completion on the deal page.
- Replaced the To-dos placeholder with an account-scoped open-action list and completion flow.
- Added domain and LiveView coverage for due ordering, overdue state, activity entries, listing, and completion from To-dos.

## Decisions not in the PRD

- Follow-up due timestamps are stored in UTC. Date-only entries are treated as due at 23:59:59 in Asia/Jakarta; entries with a time are converted from Asia/Jakarta to UTC before storage.
- The product timezone is represented with a fixed UTC+07:00 offset because Asia/Jakarta has no daylight-saving transitions and the project does not otherwise need a timezone database.
- Completed follow-ups remain visible on the deal page, while the global To-dos page intentionally lists only incomplete actions.
- Activity descriptions use `Follow-up added: ...` and `Follow-up completed: ...` so the immutable timeline remains concise and searchable.

## Notes for the next milestone

- Contacts, deal pages, activity, and To-dos remain LiveView as required; milestone 7 can add the authenticated `/app` controller/Vue entry without changing these flows.
- `Alur.Deals.list_open_next_actions/1` is the account-scoped source for any later summary or navigation indicator.

## Deviations

- None.

## Verification

- `mix precommit` passed: 129 tests, formatter, Credo, Dialyzer, ExDNA, and Reach checks.
- Focused next-action domain and LiveView coverage passed, including overdue Jakarta display, account isolation, activity logging, deal completion, and To-dos completion.
- Interactive browser automation was unavailable in this environment; visible behavior was verified through authenticated LiveView tests.
