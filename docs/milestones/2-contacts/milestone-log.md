# Milestone 2 Log — Contacts

status: passed

## What's new in the app

- **Contact Directory**: A dedicated contacts management screen at `/contacts` displaying your contact relationships with their name, company, and email address.
- **Search & Filtering**: Real-time name search allows you to quickly locate contacts. Empty state messaging displays clear guidance when no contacts match or before any contacts have been created.
- **Add New Contact**: A streamlined contact creation form at `/contacts/new` allowing you to record a person's display name (required), organization/company, email, phone number, and relationship notes.
- **Contact Details View**: Dedicated contact profile page at `/contacts/:id` presenting structured contact details including direct email (`mailto:`) and phone links, associated organization, and formatted notes.
- **Edit & Delete**: Full capability to update contact details (`/contacts/:id/edit`) or remove contacts both from their profile page and directly from the directory table.
- **Multi-tenant Account Privacy**: Strict database-level and scope-level tenant isolation ensuring that all contacts belong exclusively to your signed-in account and can never be seen or modified by other accounts.
- **Depot Design Fidelity**: Fully styled in Depot dark server-rack styling using Carbon (`#04040b`) canvas, Graphite surfaces, Basalt hairline dividers, Red Hat typography, and Signal Green primary CTA.

## What was built

### Models and Schemas
- `Alur.Contacts.Contact` (`lib/alur/contacts/contact.ex`): Ecto schema for contact records with binary ID primary key, `name` (required), optional `email`, `phone`, `company`, and `notes`, associated with `Alur.Accounts.User` through `user_id`.
- Migration: `priv/repo/migrations/20260907002040_create_contacts.exs` creating the `contacts` SQLite table with foreign key to `users` and indexed on `[:user_id]` and `[:user_id, :name]`.

### Context & Data Logic
- `Alur.Contacts` (`lib/alur/contacts.ex`): Context module accepting `%Alur.Accounts.Scope{}` as the first argument across all public functions (`list_contacts/2`, `get_contact!/2`, `get_contact/2`, `create_contact/2`, `update_contact/3`, `delete_contact/2`, `change_contact/3`) enforcing user account ownership.

### Views, LiveViews & Templates
- `AlurWeb.ContactLive.Index` (`lib/alur_web/live/contact_live/index.ex`): LiveView for the directory list, search filtering, quick actions, and empty states.
- `AlurWeb.ContactLive.Form` (`lib/alur_web/live/contact_live/form.ex`): LiveView form handling both contact creation (`:new`) and contact updates (`:edit`).
- `AlurWeb.ContactLive.Show` (`lib/alur_web/live/contact_live/show.ex`): LiveView detail page showing all contact attributes with navigation breadcrumb, edit, and deletion capabilities.

### Routes
Added to `lib/alur_web/router.ex` inside the authenticated scope `[:browser, :require_authenticated_user]` and `live_session :require_authenticated_user`:
- `live "/contacts", ContactLive.Index, :index`
- `live "/contacts/new", ContactLive.Form, :new`
- `live "/contacts/:id", ContactLive.Show, :show`
- `live "/contacts/:id/edit", ContactLive.Form, :edit`

### Tests & Verification
- `test/alur/contacts_test.exs`: Context unit tests verifying listing, searching, isolation, getters, creation, updates, and deletion.
- `test/alur_web/features/contacts_test.exs`: Comprehensive end-to-end `PhoenixTest` feature suite verifying:
  - Creating a contact from `/contacts` and verifying presence of name, company, and email in directory.
  - Finding contacts by name search and resetting search.
  - Opening the contact detail view to inspect all attributes.
  - Editing contact details and verifying updates.
  - Deleting contacts from the detail page and from the directory table.
  - Required field validations on the creation form.
  - Multi-tenant isolation: another account cannot see, search for, or access contacts created by another user.
- `test/alur_web/live/contact_live/index_test.exs`: LiveView tests for directory mounting, unauthenticated redirect, search events, and table row deletion.
- `test/alur_web/live/contact_live/show_test.exs`: LiveView tests for detail page rendering, contact deletion, and unauthorized access rejection.
- `test/alur_web/live/contact_live/form_test.exs`: LiveView tests for new and edit forms, validation errors, and redirects.
- Full verification gate passed: `mix precommit` (`compile --warnings-as-errors`, `format --check-formatted`, `test`, `credo --strict`, `dialyzer`, `ex_dna`, `reach.check`).

## Decisions not in the PRD

- **Routing Structure**: Implemented separate LiveViews (`ContactLive.Index`, `ContactLive.Form`, and `ContactLive.Show`) with explicit distinct URLs (`/contacts`, `/contacts/new`, `/contacts/:id`, `/contacts/:id/edit`). This provides clean bookmarkable URLs, direct linkability, and straightforward navigation in accordance with Phoenix best practices.
- **Redirection after Creation**: After successfully submitting the "New contact" form, the user is redirected to `/contacts` with an info flash notice so they immediately see the new contact in their directory and can exercise search/filtering. Updating a contact redirects to `/contacts/:id` to view the updated details.
- **Synchronous ExUnit Execution for SQLite**: Configured database-touching test cases to run synchronously (`use AlurWeb.ConnCase` / `use Alur.DataCase` without `async: true`) to prevent concurrent file access lock errors (`Database busy`) specific to SQLite in high test parallelism.

## Notes for the next milestone (Milestone 3 — Deals)

- In Milestone 3, deals will be attached to contacts:
  - Each deal will have a title, IDR value, starting column (`Lead`, `Meeting`, `Proposal`, `Won`, `Lost`), optional notes, and a required contact foreign key (`contact_id`).
  - Contact detail page (`/contacts/:id` in `ContactLive.Show`) is already structured to accommodate the list of deals attached to that contact and a "New deal" button.
  - Deal amounts should be formatted in Indonesian Rupiah (`Rp 15.000.000`).

## Deviations and why

None. All features strictly follow Milestone 2 specifications without implementing deals, Kanban, or external imports.
