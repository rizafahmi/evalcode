status: passed

## What's new in the app

- Signed-in users can create a deal from a contact with a title, IDR value, pipeline column, and optional notes.
- Contact pages now list their deals, including the current pipeline column and rupiah-formatted value.
- Deal pages show the opportunity details, allow editing all deal fields, and support deletion.
- Deal values display as Indonesian Rupiah, such as `Rp 15.000.000`.

## What was built

- Added the `Alur.Deals` context with account-scoped deal CRUD and fixed pipeline-column queries.
- Added `Alur.Deals.Deal` and `Alur.Deals.PipelineColumn` schemas.
- Added the `pipeline_columns` and `deals` tables, seeded with Lead, Meeting, Proposal, Won, and Lost.
- Added `DealsLive` routes for creating a deal from a contact and viewing/editing/deleting a deal.
- Extended contact detail pages with a deal list and New deal action.
- Added context and LiveView tests for CRUD, isolation, pipeline movement, IDR formatting, and contact display.

## Decisions not in the PRD

- Pipeline column IDs are stable lowercase slugs (`lead`, `meeting`, `proposal`, `won`, `lost`) so later milestones can persist moves without depending on display labels.
- Pipeline columns are global seeded reference data; deals and contacts remain scoped to the signed-in user, which is the account boundary established in Milestone 2.
- The deal form permits choosing any contact owned by the current user, while the entry point from a contact preselects that contact.

## Notes for the next milestone

- Kanban work can use `Alur.Deals.list_pipeline_columns/0` and `Alur.Deals.list_contact_deals/2` as the fixed-column foundation.
- Deal movement currently updates the pipeline column without activity logging, as activity belongs to Milestone 5.

## Deviations

- No Kanban board, activity log, next actions, totals, or multi-currency behavior was added.

## Verification

- `mix ecto.migrate` passed, including the fixed pipeline-column seed migration.
- `mix test` passed: 122 tests.
- `mix precommit` passed: formatter, tests, Credo, Dialyzer, ExDNA, and Reach.
- The Phoenix server started on `127.0.0.1:4000`; loopback HTTP smoke checks were blocked by the execution sandbox, while authenticated LiveView coverage passed through `Phoenix.LiveViewTest`.
