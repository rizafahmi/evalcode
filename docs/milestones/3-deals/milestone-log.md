# Milestone 3 Log — Deals

status: passed

## What's new in the app

- **Deal Creation from Contacts**: You can now create and attach sales opportunities (deals) directly to contacts from the contact details page (`/contacts/:id`).
- **Indonesian Rupiah (IDR) Formatting**: All deal values are stored and presented in Indonesian Rupiah with period thousand separators and the `Rp` prefix (e.g. `Rp 15.000.000`).
- **Five Pipeline Stages**: Deals progress through the five standard pipeline columns: `Lead`, `Meeting`, `Proposal`, `Won`, and `Lost`. New deals default to `Lead`.
- **Deal Detail View**: A dedicated deal page (`/deals/:id`) displays deal value in large Signal Green typography, current stage badge, associated contact link, and notes.
- **Instant Stage Updating on Deal Page**: You can change the deal stage directly on the deal page with a single click across stage pills or via stage select, instantly persisting the new column.
- **Edit & Delete Deals**: Full capability to update deal attributes (`/deals/:id/edit`) or remove deals directly with confirmation.
- **Contact Deals List**: Each contact detail page now showcases all active deals attached to that relationship, showing opportunity title, formatted value, stage badge, and quick access to view each opportunity.
- **Strict Multi-tenant Privacy**: All deals and contacts are strictly private to your authenticated account. Another account cannot view, edit, delete, or attach deals to your contacts.
- **Depot Design Aesthetic**: Handcrafted in Depot dark server-rack styling using near-black Carbon canvas, Graphite surfaces, Basalt hairline borders, tri-tonal typography (Red Hat Display, Text, and Mono), and Signal Green primary CTA buttons.

## What was built

### Models and Schemas
- `Alur.Deals.PipelineColumn` (`lib/alur/deals/pipeline_column.ex`): Schema for pipeline columns with binary ID primary key, `name` (unique), `order` (unique, 1-5), and `has_many :deals`.
- `Alur.Deals.Deal` (`lib/alur/deals/deal.ex`): Schema for deals with binary ID primary key, `title` (required), integer `amount` (required, >= 0), optional `notes`, belonging to `Alur.Accounts.User`, `Alur.Contacts.Contact`, and `Alur.Deals.PipelineColumn`. Includes input sanitization for amounts with symbols and dots.
- `Alur.Contacts.Contact` (`lib/alur/contacts/contact.ex`): Added `has_many :deals, Alur.Deals.Deal` association.
- Migration `priv/repo/migrations/20260907010000_create_pipeline_columns_and_deals.exs`: Creates `pipeline_columns` table, seeds the 5 columns (`Lead`, `Meeting`, `Proposal`, `Won`, `Lost`), and creates `deals` table with foreign keys to `users`, `contacts`, and `pipeline_columns` with indexes.

### Contexts & Formatting
- `Alur.Deals.Currency` (`lib/alur/deals/currency.ex`): Dedicated helper module formatting numbers into Indonesian Rupiah (`format_idr/1`).
- `Alur.Deals` (`lib/alur/deals.ex`): Context module accepting `%Alur.Accounts.Scope{}` as the first argument across all operations (`list_pipeline_columns/0`, `get_pipeline_column!/1`, `get_pipeline_column_by_name/1`, `default_pipeline_column/0`, `seed_pipeline_columns/0`, `list_deals/2`, `list_deals_for_contact/2`, `get_deal!/2`, `get_deal/2`, `create_deal/2`, `update_deal/3`, `change_deal_stage/3`, `delete_deal/2`, `change_deal/3`). Enforces strict user tenant isolation and verifies contact ownership.
- `AlurWeb.CoreComponents` (`lib/alur_web/components/core_components.ex`): Added `stage_badge/1` component and delegated `format_idr/1` to `Alur.Deals.Currency` for template access.

### Views, LiveViews & Templates
- `AlurWeb.ContactLive.Show` (`lib/alur_web/live/contact_live/show.ex`): Updated to load and display attached deals in a table with stage badges, IDR values, view links, and empty state CTA for creating a deal.
- `AlurWeb.DealLive.Show` (`lib/alur_web/live/deal_live/show.ex`): Dedicated deal detail view with back breadcrumb, deal title, value card, interactive stage changer, contact link, notes, edit button, and delete action.
- `AlurWeb.DealLive.Form` (`lib/alur_web/live/deal_live/form.ex`): LiveView handling deal creation and editing, pre-filling contact context, validating fields, and redirecting on save.

### Routes
Added inside the authenticated scope `[:browser, :require_authenticated_user]` and `live_session :require_authenticated_user` in `lib/alur_web/router.ex`:
- `live "/contacts/:contact_id/deals/new", DealLive.Form, :new`
- `live "/deals/new", DealLive.Form, :new`
- `live "/deals/:id", DealLive.Show, :show`
- `live "/deals/:id/edit", DealLive.Form, :edit`

### Tests & Verification
- `test/alur/deals_test.exs`: Context unit tests for currency formatting, pipeline columns listing, deal creation, validation, string sanitization, updates, stage changing, deletion, and cross-account isolation.
- `test/alur_web/features/deals_test.exs`: Comprehensive end-to-end `PhoenixTest` feature suite verifying:
  - Creating a deal from a contact.
  - Viewing the deal with Indonesian Rupiah formatting (`Rp 15.000.000`).
  - Changing the pipeline stage directly on the deal page.
  - Verifying the deal is listed on the contact's page with the new stage.
  - Deleting the deal and verifying it is removed from the contact.
  - Cross-account isolation: another user cannot view or edit deals created by another user.
- `test/alur_web/live/deal_live/show_test.exs`: LiveView tests for deal show page, unauthenticated redirects, stage changing, deletion, and unauthorized access rejection.
- `test/alur_web/live/deal_live/form_test.exs`: LiveView tests for deal create and edit forms, validation errors, and redirects.
- Full verification gate passed: `mix precommit` (`compile --warnings-as-errors`, `format --check-formatted`, `test`, `credo --strict`, `dialyzer`, `ex_dna --max-clones 0`, `reach.check --arch --smells`).

## Decisions not in the PRD

- **Direct Stage Selector on Deal Page**: Added interactive stage buttons directly on `DealLive.Show` in addition to the edit form, fulfilling "change the column on the deal page" with minimal friction while maintaining Depot styling.
- **Flexible Amount Parsing**: Implemented amount sanitization in `Deal.changeset/2` to gracefully handle input strings containing currency prefixes or thousand separator dots (e.g. `"Rp 15.000.000"` or `"15000000"`), casting them to integer values.
- **Migration-level Pipeline Columns Seeding**: Seeded the 5 standard pipeline columns within the database migration using deterministic UUIDs so all test sandboxes, dev environments, and production databases immediately have columns available without requiring manual seed scripts.
- **Contact Foreign Key Isolation**: In `Alur.Deals.create_deal/2` and `update_deal/3`, verified that the specified `contact_id` belongs to the authenticated user scope, preventing cross-tenant data association tampering.

## Notes for the next milestone (Milestone 4 — Kanban pipeline)

- Milestone 4 will turn `PipelineLive` (`/`) into an interactive Kanban board:
  - Five columns in order: `Lead`, `Meeting`, `Proposal`, `Won`, `Lost`.
  - Each card will display deal title, contact name, and formatted IDR value (`format_idr(deal.amount)`).
  - Dragging a card between columns updates its `pipeline_column_id` via LiveView event.
  - Column totals calculated per column in IDR.
  - Clicking a card opens `~p"/deals/#{deal}"`.

## Deviations and why

None. Implemented only Milestone 3 as specified in the PRD without pre-building Kanban drag-and-drop or activity logging.
