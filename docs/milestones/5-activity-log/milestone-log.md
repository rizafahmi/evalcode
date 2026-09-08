status: passed

## What's new in the app

- Deal pages now show a newest-first activity history with UTC date/time and short descriptions.
- Creating a deal automatically records a creation entry.
- Moving a deal, including a Kanban drag, records the old and new pipeline columns.
- Users can add free-text notes to a deal activity log; entries cannot be edited or deleted.

## What was built

- Added the `activities` table and `Alur.Deals.Activity` schema, account-scoped to both the user and deal.
- Added activity listing, note changesets, note creation, and transaction result helpers to `Alur.Deals`.
- Deal creation and pipeline movement now use `Ecto.Multi` so the deal change and automatic activity entry succeed or fail together.
- Added `has_many :activities` to deals and delete cascading through the deal foreign key.
- Extended `DealsLive` with the activity timeline and manual note form while preserving the existing authenticated deal routes.
- Added domain and LiveView coverage for creation, movement, newest-first ordering, note submission, and account isolation.

## Decisions not in the PRD

- Activity timestamps use UTC with microsecond precision so entries created within the same second still sort reliably newest-first. The UI labels timestamps as UTC.
- Activities are exposed through the existing `Alur.Deals` context rather than a separate top-level context because they are immutable records owned by a deal.
- Automatic descriptions use concise sentences such as `Deal created in Lead.` and `Moved from Lead to Meeting.`.

## Notes for the next milestone

- `Deals.create_activity/3` is the hook for next-action add/complete entries.
- `Deals.list_deal_activities/2` is account-scoped and already returns newest-first entries.
- The activity foreign key cascades when a deal is deleted, so no orphaned log records remain.

## Deviations

- None.

## Verification

- `mix format` passed.
- `mix test` passed: 127 tests.
- `mix precommit` passed: formatter, tests, Credo, Dialyzer, ExDNA, and Reach/architecture checks.
