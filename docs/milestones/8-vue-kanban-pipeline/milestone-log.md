status: failed

## What's new in the app

- Signed-in users can open `/app` and see their deals in a Vue Kanban with Lead, Meeting, Proposal, Won, and Lost columns.
- Each card shows the deal title, contact, and Indonesian Rupiah amount; columns show card counts and totals.
- Dragging a card to another column persists the move through `PATCH /api/deals/:id`, and clicking a card opens the existing LiveView deal page.
- The JSON API uses the existing session cookie and returns `401` JSON for unauthenticated requests.

## What was built

- Added authenticated REST routes for `GET /api/deals`, `GET /api/deals/:id`, and `PATCH /api/deals/:id`.
- Added `AlurWeb.Api.DealController`, with account-scoped serialization and `Deals.move_deal/3` for movement so activity logging remains intact.
- Added a JSON API authentication plug that reuses the browser session without redirecting API clients.
- Replaced the Vue scaffold in `assets/vue/main.ts` with the five-column board and native drag/drop behavior.
- Added Vitest coverage for loading cards into columns and issuing the PATCH move request.
- Added ConnCase coverage for API authentication, listing, detail access, account isolation, and move activity logging.

## Decisions not in the PRD

- The board keeps the seeded pipeline columns in the frontend as a small fixed constant, matching the locked product order; no optional `/api/pipeline` endpoint was needed.
- The move endpoint returns the fully preloaded deal after calling `move_deal/3`, so the API response remains consistent with list/detail payloads and includes the contact.
- A failed drag request rolls the card back to its previous column and shows the same compact error state as an initial load failure.

## Notes for the next milestone

- Install frontend dependencies in `assets/` and run `npm --prefix assets test`; the current sandbox has no `assets/node_modules` and the install did not complete.
- Re-run `mix precommit` in an environment that permits Mix's TCP filesystem lock; its constituent formatter, Credo, and test checks were run separately here.

## Deviations

- Required Vitest and browser checks could not be completed because frontend dependencies were unavailable in the sandbox. `npm --prefix assets test` exits with `vitest: command not found`.
- `mix precommit` could not acquire Mix's TCP filesystem lock (`:eperm`) in this sandbox, although `mix format --check-formatted`, `mix credo --strict`, and `mix test` each passed independently.

## Verification

- `mix format --check-formatted` passed.
- `mix credo --strict` passed with no issues.
- `mix test` passed: 136 tests.
- `npm --prefix assets test` was attempted but could not start because `assets/node_modules` is absent and `vitest` is unavailable.
- Interactive browser verification was not completed because the frontend toolchain could not be installed in this sandbox.
