# Milestone 2 — Contacts

status: passed

## What's new in the app

- The **Contacts** page is now a real list instead of a placeholder: every contact you add shows their name, company, and email.
- **Add a contact** from the list — only a name is required; email, phone, company, and notes are optional.
- **Search as you type**: the list filters by name (case-insensitive, partial match) as you type, and the search term lives in the URL so it survives a refresh. A search that matches nobody shows its own empty state with a one-click clear.
- **Open a contact** to see their page with all their details — email and phone are clickable links.
- **Edit any field** from the contact's page, and **delete** the contact (with a confirmation prompt).
- Contacts are private to your account: another account never sees your contacts, and even typing in their contact's web address only sends you back to your own list.
- Everything keeps the Depot dark server-console look: carbon canvas, hairline basalt borders, graphite cards, one signal-green call-to-action per page, Red Hat type.

## What was built

### Files, models, routes

- **Schema** — `lib/alur/contacts/contact.ex` (`Alur.Contacts.Contact`), table `contacts`: `name` (required, ≤ 120 chars), optional `email` / `phone` / `company` / `notes`, `belongs_to :account`, binary_id keys + `utc_datetime` timestamps. `notes` is a `:text` column in SQLite so free text can be long.
- **Migration** — `priv/repo/migrations/20250101000002_create_contacts.exs`: `account_id` references `accounts (type: :binary_id, on_delete: :delete_all)` per the milestone-1 notes, plus an index on `account_id`.
- **Context** — `lib/alur/contacts.ex` (`Alur.Contacts`): `list_contacts(account, search \\ "")`, `get_contact(account, id)`, `create_contact(account, attrs)`, `update_contact/2`, `delete_contact/1`, `change_contact/2`. Every read takes the owning `%Account{}`; queries filter `account_id` so one account can never touch another's rows. `create_contact` stamps `account_id` from the account and the changeset never casts it, so ownership can't be changed through a form.
- **Name search** is done in SQL with `instr(lower(name), lower(term)) > 0`: case-insensitive substring match with no wildcard-escaping edge cases. Sorting is by lowercased name then name.
- **Routes** (`lib/alur_web/router.ex`, inside the existing `live_session :authenticated`): `live "/contacts" :index`, `live "/contacts/new" :new`, `live "/contacts/:id" :show`, `live "/contacts/:id/edit" :edit`. All stay behind the existing auth hook.
- **LiveView** — `lib/alur_web/live/contacts_live.ex` (`AlurWeb.ContactsLive`) grew from the milestone-1 placeholder into one module driving all four routes via `live_action`: a searchable list (Depot table with name/company/email and per-row open link, contact-count header), shared new/edit form (validate-on-change + save), and a show page with a details card, `mailto:`/`tel:` links, edit, and confirmed delete. Two empty states: "No contacts yet" (first-run, with a New-contact CTA) and "No contacts found" (empty search result, with a clear-search action).
- Foreign/missing contact ids in `:show`/`:edit` are handled gracefully: a scoped `get_contact` returning `nil` sends the visitor back to `/contacts` with a "Contact not found." flash — no crash, no 500, no existence leak between accounts.
- **No new dependency** was needed, so `mix igniter.add` was not used.

### Tests (40 total, all green via `mix test`)

- `test/alur/contacts_test.exs` (10) — account-scoped create/list/get; name required with everything else optional; malformed email rejected; list ordering; case-insensitive name filtering; only-name-is-searched; cross-account `get_contact` → nil; update never changes the owner; delete removes the row.
- `test/alur_web/features/contacts_test.exs` (3, PhoenixTest) — the full lifecycle from the UI: add a contact with all fields → opens its page with a created flash → back to a list that shows it → add a second → search narrows to one name → clearing restores both → no-match search shows its empty state → clear returns the list → open → edit prefilled values → updated flash and page → delete → gone from the list; cross-account isolation (directly opening another account's contact redirects with "Contact not found."); and form validation errors (blank name, malformed email).
- Existing milestone-1 tests still pass unchanged (`register_and_shell_test.exs` still sees "No contacts yet" on a fresh account's Contacts page).

### Verification

- `mix test` — 40 tests, 0 failures (feature tests re-run 3× for stability).
- `mix format --check-formatted` — clean. `mix credo --strict` — no issues. `mix compile --warnings-as-errors` — clean.
- HTTP checks against a running dev server (`mix phx.server`): logged-out `GET /contacts` → 302 to `/accounts/log-in`; register → signed-in; `GET /contacts` renders the empty state; `GET /contacts/new` renders the form; a bogus contact id (`/contacts/not-a-contact`) redirects back to `/contacts` without erroring.

## Decisions and deviations (not in the PRD)

1. **Optional email gets a light format check** ("must have the @ sign and no spaces", same rule as accounts) but only when a value is present — blank/no email is fine. The PRD says email is optional and doesn't ask for validation; this prevents obviously broken addresses without requiring them.
2. **Foreign/missing contact page → redirect, not 404.** A scoped lookup that returns `nil` redirects to `/contacts` with a "Contact not found." notice. This keeps isolation airtight (the visitor can't tell whether the id exists but belongs to someone else) without leaking 404 vs. 200 differences, and avoids raw error pages in the signed-in shell.
3. **Search semantics**: substring match on the *name* only, case-insensitively, matching the PRD's "search/filter the list by name". Company/email are not searched.
4. **Search term lives in the URL** (`/contacts?q=…`) via live patch — cheap, shareable, survives reload, and the empty search is normalized to no query string at all.
5. **Delete is offered on the contact page** (with a `data-confirm` prompt), not per-row on the list — keeps the list clean; the done-when only requires delete to exist.
6. **One LiveView module for the four routes** using `live_action` + scoped assigns, matching this repo's single-module-per-section style from milestone 1 (no separate `Index`/`Show`/form-component files, no extra HTML modules).
7. **Delete/edit call only account-scoped records**: `handle_event`/`apply_action` operate on contacts already fetched through `Contacts.get_contact/2`, so an account can't edit or delete another account's contact even by driving events.
8. The show page carries a muted "Deals for this contact arrive in the next milestone." note so users aren't surprised, but **no deal functionality was built** (out of scope for this milestone).
9. Depot-styling notes: the delete action uses the rose error palette (already used by form errors app-wide) on a ghost-style button because the Depot palette has no destructive token; signal green stays reserved for the single per-page primary CTA.

## Notes for the next milestone

- Milestone 3 (Deals) will add a `deals` table referencing `contacts` with `references(:contacts, type: :binary_id, on_delete: :delete_all)` and `accounts`, plus the five seeded pipeline columns (Lead → Lost).
- Reuse the ownership pattern here: a `get_deal(account, id)`-style scoped fetch feeding the deal LiveView, exactly like `Contacts.get_contact/2`.
- The contact show page is where deals will be listed and where the "start a new deal" entry point will live; the teaser text there should be replaced by the real deals panel.
- `Contacts.list_contacts/2` currently returns plain lists; milestone 4+ boards and future streams may want preloads or `streams`, but nothing in the UI needs that yet.
- SQLite async gotcha still applies: every DB-writing test module is `async: false`.

## Gate used

`mix format --check-formatted`, `mix credo --strict`, full `mix test` — all clean/green.
No commit was made by this worker (the parent orchestrator commits each green milestone per `docs/run-autonomous.md`).
