# Sorak MVP Product Requirements and Technical Specification

## Status

- Product contract: approved
- Implementation: not started
- Initial market: Indonesia
- Initial deployment model: single-node VPS

## Problem Statement

Indonesian live-stream creators need a simple way to receive donation events, understand their donation activity, and display timely donation alerts in streaming software such as OBS. Existing systems often combine payment processing, creator tooling, and overlays into a large product surface. Sorak's first release focuses on the smallest complete platform boundary: creator accounts, simulated payment events, useful donation analytics, and reliable realtime overlays.

The MVP must prove that a payment event can move safely from an authenticated gateway boundary into an immutable event history, creator dashboard, and OBS alert without introducing real payment processing or a donor checkout flow.

## Solution

Sorak is an Indonesia-first, multi-creator web application with:

1. LiveView registration and login for creators.
2. A Vue dashboard for donation analytics, event history, account controls, onboarding, and overlay configuration.
3. A signed REST webhook that simulates a payment gateway.
4. A Phoenix LiveView overlay that OBS can capture as a transparent browser source.
5. Phoenix PubSub and Channels for realtime overlay and dashboard updates.
6. SQLite persistence through Ecto.
7. A production-ready single-node Docker Compose deployment behind Caddy.

User-facing content is in Bahasa Indonesia. Code, API vocabulary, logs, tests, and developer documentation are in English. Currency and dates use Indonesian formatting and the Asia/Jakarta timezone.

## Goals

1. Let multiple creators independently register and manage their Sorak accounts.
2. Accept authenticated, idempotent payment lifecycle events from a simulated gateway.
3. Keep an immutable, auditable history of pending, paid, and failed payment transitions.
4. Show creators accurate gross paid-donation analytics.
5. Deliver one realtime alert for each payment that first becomes paid.
6. Recover recent missed overlay alerts after a temporary disconnect without replaying stale history.
7. Provide a polished, responsive, gaming-neon creator experience.
8. Produce a repository that can be verified in CI and deployed to a single VPS.

## Success Criteria

The MVP is ready when:

1. A creator can register, log in, configure an overlay, and complete onboarding.
2. A valid signed webhook can create and transition a payment.
3. Duplicate or stale webhook events cannot duplicate revenue or alerts.
4. A paid transition updates the creator dashboard and all connected overlay clients in realtime.
5. A reconnecting overlay catches up eligible recent alerts within the agreed limits.
6. Dashboard totals and the 30-day chart count only paid donations.
7. The fixed dashboard test donation behaves exactly like a normal paid donation.
8. The application passes backend, frontend, and browser-level verification.
9. The production Compose stack starts with persistent SQLite storage, HTTPS routing, a health check, and documented backup and restore procedures.

## Actors

### Creator

Registers, logs in, reviews donation activity, configures alerts, manages account settings, and connects Sorak to OBS.

### Simulated Payment Gateway

Sends HMAC-signed payment lifecycle webhooks using a deployment-wide secret and a creator-specific public recipient key.

### Overlay Viewer

An OBS browser source or browser holding a creator's secret overlay URL. It can receive alerts but cannot mutate creator or payment data.

### Operator

Deploys and maintains the single-node service. The MVP has no operator-facing admin UI.

## User Stories

1. As a creator, I want to register with email and password, so that I can manage my own Sorak workspace.
2. As a creator, I want to log in and out securely, so that my dashboard is private.
3. As a creator, I want to edit my display name, so that Sorak uses the identity I present to my audience.
4. As a creator, I want to change my password, so that I can maintain account security.
5. As a creator, I want a secret overlay URL, so that OBS can receive alerts without an interactive login.
6. As a creator, I want to copy my overlay URL, so that adding Sorak to OBS is straightforward.
7. As a creator, I want to rotate my overlay URL, so that I can revoke a leaked URL.
8. As a creator, I want a first-run OBS checklist, so that I know how to make the overlay work.
9. As a creator, I want to send a fixed test donation, so that I can verify the complete alert path.
10. As a creator, I want the test donation to be a normal paid donation, so that testing uses the same behavior as production events.
11. As a creator, I want to see today's paid donation amount, so that I can understand current performance.
12. As a creator, I want to see the last 30 days of paid donation revenue, so that I can understand recent performance.
13. As a creator, I want to see my paid donation count, so that I can distinguish volume from total value.
14. As a creator, I want a 30-day daily revenue chart, so that I can see trends over time.
15. As a creator, I want dashboard data to update without refreshing, so that I can monitor a live stream.
16. As a creator, I want to see recent donations on the overview, so that the latest activity is immediately visible.
17. As a creator, I want a paginated payment history, so that a long history remains usable.
18. As a creator, I want to filter history by pending, paid, or failed status, so that I can inspect a specific lifecycle state.
19. As a creator, I want to inspect a payment's transition history, so that I can understand how it reached its current state.
20. As a creator, I want payment records to remain immutable, so that revenue and audit history cannot silently change.
21. As a creator, I want pending and failed payments visible but excluded from revenue, so that the dashboard is transparent and accurate.
22. As a creator, I want exactly one alert when a payment first becomes paid, so that duplicate webhooks do not annoy viewers.
23. As a creator, I want all connected OBS clients to receive an alert, so that the same overlay URL works across streaming setups.
24. As a creator, I want donation bursts queued in order, so that alerts do not overlap.
25. As a creator, I want recent alerts recovered after a temporary disconnect, so that a brief network interruption does not silently lose donations.
26. As a creator, I want stale alerts skipped after a long interruption, so that OBS does not replay an obsolete backlog.
27. As a creator, I want a fresh overlay browser to start from the present, so that adding a source does not replay history.
28. As a creator, I want to configure alert accent color, so that the alert can match my stream.
29. As a creator, I want to configure alert duration, so that the alert fits my broadcast pacing.
30. As a creator, I want to configure a minimum alert amount, so that small donations can remain in history without appearing on stream.
31. As a creator, I want to enable or disable the bundled sound, so that I control the audio experience.
32. As a creator, I want donor name, amount, and message escaped and rendered as plain text, so that untrusted input cannot inject markup.
33. As a creator, I want the dashboard to work on mobile and desktop, so that I can monitor activity away from my streaming computer.
34. As a creator, I want the overlay to scale on a 16:9 canvas, so that it works across common OBS resolutions.
35. As a gateway, I want to address a creator using a public recipient key, so that routing does not expose account or overlay secrets.
36. As a gateway, I want to send pending, paid, and failed states, so that Sorak can track a payment lifecycle.
37. As a gateway, I want repeated events to be idempotent, so that safe retries are possible.
38. As an operator, I want invalid signatures and stale requests rejected, so that untrusted callers cannot create donations.
39. As an operator, I want malformed or oversized payloads rejected, so that the webhook boundary remains safe.
40. As an operator, I want normalized event data retained without raw webhook bodies, so that debugging remains possible without unnecessary payload retention.
41. As an operator, I want a health endpoint, so that the reverse proxy and deployment tooling can detect application availability.
42. As an operator, I want documented SQLite backup and restore commands, so that persistent data can be recovered.
43. As an operator, I want automated CI verification, so that regressions are caught before deployment.

## Functional Requirements

### Creator Authentication

1. Registration is open and does not require an invitation.
2. Authentication uses Phoenix session cookies and generated password-hashing conventions.
3. Registration and login are rendered with LiveView.
4. Email addresses are unique and immutable in the MVP.
5. Email verification, password-reset delivery, OAuth, organizations, and team accounts are excluded.
6. Authenticated creator routes must not disclose another creator's data.

### Account Management

1. The Vue dashboard allows a creator to edit their display name.
2. The creator can change their password after supplying the required current credentials.
3. The creator can view, copy, and rotate the secret overlay URL.
4. Rotating the overlay token immediately invalidates the previous URL.
5. Account deletion, avatars, social links, and public profiles are excluded.

### Payment Lifecycle

1. A payment's current status is one of `pending`, `paid`, or `failed`.
2. A payment may be created directly in any valid status.
3. A pending payment may transition to paid or failed.
4. Paid and failed are terminal.
5. Repeated events do not create duplicate transitions.
6. Stale events cannot regress a payment.
7. Conflicting immutable payment details are rejected rather than silently overwritten.
8. Exactly one overlay alert is emitted when a payment first transitions to paid, including direct creation as paid.
9. Pending and failed events never emit donation alerts.

### Donation Data

Each payment contains:

- A gateway-scoped external payment identifier.
- The owning creator.
- A public recipient key used for creator routing.
- Current status.
- Amount as a 64-bit integer number of rupiah.
- Optional donor display name.
- Optional public message.
- Gateway occurrence timestamp.
- Local creation and update timestamps.

Validation rules:

- Amount must be between Rp1.000 and Rp100.000.000 inclusive.
- Donor name is optional and limited to 50 characters.
- Message is optional and limited to 280 characters.
- Missing or blank donor names display as "Anonim".
- Name and message are plain text and are HTML-escaped at rendering boundaries.
- No donor email, phone number, or other contact data is accepted.

### Transition Audit

1. Every accepted gateway event has a unique external event identifier.
2. Accepted events produce immutable transition records.
3. Transition records include a monotonically increasing local sequence, external event identifier, requested status, previous status when present, occurrence timestamp, and receipt timestamp.
4. Raw webhook bodies and headers are not retained after processing.
5. Normalized payment and transition records are retained indefinitely.
6. Creators cannot edit or delete payment or transition records.

### Dashboard Overview

The overview displays:

1. Gross paid donation amount for the current Asia/Jakarta calendar day.
2. Gross paid donation amount for the trailing 30 Asia/Jakarta calendar days.
3. Paid donation count for the same 30-day period.
4. Daily gross paid donation totals for the last 30 calendar days.
5. Recent payment activity across all statuses.

Revenue means gross paid donation amount. It does not represent net fees, refunds, available balance, or completed payouts.

The chart should use a lightweight native SVG implementation rather than a general charting dependency.

### Event History

1. History is cursor-paginated.
2. A creator can filter by pending, paid, or failed current status.
3. Each row shows donor label, amount, status, and relevant timestamps.
4. A detail view shows immutable payment data and the ordered transition audit.
5. Search, custom date ranges, CSV export, editing, and deletion are excluded.

### Alert Settings

Each creator has one alert configuration with:

- Accent color.
- Display duration.
- Minimum paid donation amount required to alert.
- Bundled sound enabled or disabled.

Defaults:

- Every valid paid amount is eligible.
- Duration is six seconds.
- Sound is enabled.
- Playback is first-in, first-out.
- Placement is fixed at top center with safe margins.

The alert displays donor label, Indonesian-formatted amount, and message. The message area is visually capped so the overlay cannot expand without bound.

### Dashboard Test Donation

1. The overlay settings area exposes one authenticated test action.
2. The action creates a fixed localized sample donation through the same domain ingestion interface used after webhook authentication.
3. The sample is created directly as paid.
4. It is indistinguishable from a normal donation in history and analytics.
5. It contributes to revenue, is immutable, and triggers connected overlays.
6. The gateway HMAC secret is never exposed to browser code.

### Creator Onboarding

The first-run checklist contains:

1. Copy the secret overlay URL.
2. Add it to OBS as a 1920×1080 Browser Source.
3. Send the fixed test donation and observe the alert.

The checklist is marked complete when the authenticated test action succeeds. Static OBS setup instructions remain available afterward.

## API Contract

### API Boundaries

1. The JSON API exists for the same-origin Vue dashboard.
2. The signed payment webhook is the only external API.
3. The overlay is a LiveView and does not consume the dashboard JSON API.
4. There are no public creator read endpoints, creator API keys, or third-party integration APIs.
5. Browser mutations use session authentication and CSRF protection.

### Dashboard API

The dashboard requires authenticated endpoints for:

- Current creator/session data.
- Overview analytics and recent activity.
- Paginated, filtered payment history.
- Payment and transition detail.
- Reading and updating alert settings.
- Updating account profile and password.
- Rotating the overlay token.
- Creating the fixed test donation.

Responses use a consistent JSON error envelope with stable machine-readable codes and Bahasa Indonesia display messages where the browser needs to present an error.

### Signed Gateway Webhook

The external contract is a versioned payment-events endpoint.

Required headers:

- A Unix request timestamp.
- An HMAC-SHA256 signature computed from the timestamp and exact raw request body.
- JSON content type.

Required payload fields:

- Schema version.
- External event identifier.
- External payment identifier.
- Creator recipient key.
- Requested status.
- Amount in integer rupiah.
- Event occurrence timestamp.

Optional payload fields:

- Donor display name.
- Donation message.

Boundary behavior:

1. Signature comparison is constant-time.
2. Requests outside a five-minute clock-skew window are rejected.
3. Request bodies have a small explicit maximum size.
4. External event identifiers are idempotency keys.
5. The combination of gateway identity and external payment identifier uniquely identifies a payment.
6. Unknown recipient keys are rejected without exposing creator details.
7. Valid duplicates return a successful idempotent response.
8. Invalid transitions or conflicting immutable fields return a conflict response.
9. Database changes and the decision to broadcast occur atomically; broadcast happens only after commit.

## Realtime Contract

### Dashboard Channel

1. Vue connects to a Phoenix Channel using the authenticated creator session.
2. Channel authorization derives the creator identity on the server; the browser cannot select another creator.
3. Accepted payment transitions update event rows immediately.
4. First transitions to paid also refresh overview totals and chart data.
5. REST remains authoritative for initial loads and reconnect reconciliation.

### Overlay PubSub

1. A valid secret overlay token resolves to exactly one creator.
2. Every connected overlay client subscribes to that creator's alert topic.
3. A paid transition is published once after its transaction commits.
4. Each overlay keeps its own FIFO playback queue.
5. Multiple clients using the same valid URL all receive the same eligible alert.
6. Rotated tokens cannot establish new sessions.

### Overlay Cursor and Catch-Up

1. The browser stores the last displayed transition sequence locally.
2. A fresh browser with no cursor subscribes and establishes the current sequence as its baseline; it does not replay history.
3. A reconnecting browser requests paid transitions after its cursor.
4. Catch-up includes only events from the previous 10 minutes and is capped at 50 alerts.
5. Older skipped events advance the cursor so they do not appear later.
6. Alert threshold eligibility uses the creator's current saved settings.
7. The cursor advances after an alert is displayed, not merely received.
8. Normal live events received while connected remain FIFO even when a burst exceeds 50 events.

## Frontend Experience

### Information Architecture

The authenticated Vue workspace contains:

1. Overview.
2. Payment history.
3. Overlay and onboarding.
4. Account settings.

Registration and login remain LiveView screens. The overlay is a separate transparent LiveView route.

### Visual Direction

1. The product uses a gaming-neon visual language.
2. Surfaces are near-black with electric cyan as the primary operational accent and magenta for live energy.
3. Numeric data uses high-contrast, tabular styling.
4. The dashboard is dense but readable and avoids generic grids of decorative cards.
5. The Sorak identity is immediately visible on authentication and dashboard screens.
6. All interactive controls have visible focus states and WCAG AA contrast.
7. Motion respects reduced-motion preferences.

### Motion

1. Dashboard sections use a brief, restrained entrance sequence.
2. Realtime payment changes use a short status or row pulse.
3. Donation alerts use a distinct reveal, hold, and exit sequence.
4. Alert motion never causes multiple queued donations to overlap.
5. The bundled sound is original or programmatically generated and carries no third-party licensing requirement.

### Responsive Behavior

1. The dashboard is desktop-optimized but fully usable on mobile.
2. The transparent overlay is designed for 1920×1080 and scales safely to other 16:9 canvases.
3. Alert placement is fixed at top center.
4. Arbitrary aspect ratios, position presets, and drag-and-drop layout editing are excluded.

## Architecture

### Deployment Shape

Sorak is one Phoenix application and one application deployment:

- Phoenix serves HTML, LiveView, JSON, Channels, and static assets.
- Vue is compiled into Phoenix's static assets with Vite.
- LiveView powers authentication and the OBS overlay.
- Ecto persists to SQLite.
- Phoenix PubSub connects committed payment transitions to Channels and overlays.

There is no umbrella and no independently deployed frontend.

### Major Modules

#### Accounts

Owns creator registration, session authentication, display name, password changes, recipient keys, and overlay-token rotation. It exposes a narrow creator/session interface and never exposes credential fields.

#### Payments

Owns payment validation, monotonic lifecycle transitions, idempotency, immutable transition events, and the one-time paid decision. This is the primary deep domain module: callers submit a normalized command and receive a committed result describing whether state changed and whether a paid alert was created.

#### Gateway Verification

Owns raw-body signature verification, timestamp freshness, payload decoding, and conversion into a normalized payment command. It does not write directly to payment tables.

#### Analytics

Owns Asia/Jakarta revenue aggregation, 30-day daily series, counts, and recent activity queries. It exposes creator-scoped result shapes suitable for JSON serialization.

#### Alerts

Owns creator alert settings, paid-event eligibility, alert payload construction, overlay-token lookup, recent catch-up queries, and PubSub topic boundaries.

#### Creator Realtime

Owns authenticated Phoenix Channel joins and creator-scoped dashboard notifications.

#### Overlay LiveView

Owns overlay connection, alert queue presentation, browser cursor coordination, sound playback hooks, and transparent rendering.

#### Dashboard SPA

Owns authenticated navigation, API state, Channel reconciliation, Indonesian formatting, charts, onboarding, event history, alert controls, and account controls.

### Data Model

#### Creator

- Unique email.
- Password hash.
- Display name.
- Public recipient key.
- Secret overlay token digest or equivalent non-plaintext lookup representation.
- Onboarding completion timestamp.
- Creation and update timestamps.

#### Session Token

Managed using Phoenix authentication conventions.

#### Alert Settings

- Creator identity, unique.
- Accent color.
- Duration.
- Minimum alert amount.
- Sound-enabled flag.
- Creation and update timestamps.

#### Payment

- Creator identity.
- Gateway identity.
- External payment identifier.
- Current status.
- Amount in integer rupiah.
- Optional donor name.
- Optional message.
- Gateway occurrence timestamp.
- Paid timestamp when applicable.
- Creation and update timestamps.

The gateway identity and external payment identifier form a unique constraint.

#### Payment Event

- Monotonic local sequence.
- Payment identity.
- Unique external event identifier.
- Previous status when applicable.
- Requested status.
- Gateway occurrence timestamp.
- Receipt timestamp.

Payment events are append-only.

### SQLite Requirements

1. Production runs as one Phoenix application instance.
2. SQLite uses WAL mode and an explicit busy timeout suitable for the single-node workload.
3. The database lives on a persistent Docker volume.
4. Schema migrations run as an explicit release step.
5. Backup uses SQLite's online backup mechanism rather than copying a live database file directly.
6. Restore procedures require application write traffic to be stopped or otherwise safely coordinated.
7. Horizontal application scaling is excluded while SQLite is the primary store.

## Security and Privacy

1. Creator data is scoped server-side on every authenticated query and mutation.
2. Session cookies use secure production settings behind HTTPS.
3. Browser mutations use CSRF protection.
4. Passwords are hashed using Phoenix's generated authentication conventions.
5. Webhook signatures are checked before payload processing.
6. Gateway and application secrets come from runtime environment variables and never enter browser assets.
7. Overlay tokens are high-entropy, revocable bearer credentials.
8. Overlay URLs are not included in normal application access logs.
9. Recipient keys are public routing identifiers and grant no read or write access.
10. User-provided text is rendered as escaped plain text.
11. Request and field size limits protect webhook and rendering boundaries.
12. Raw webhook bodies are discarded after validation and normalization.
13. No donor contact PII is collected.
14. No automated profanity filtering or creator hide-message control is included.

## Deployment and Operations

### Production Stack

The repository provides:

1. A multi-stage production image for Phoenix and compiled Vue assets.
2. Docker Compose services for Sorak and Caddy.
3. A persistent SQLite volume.
4. Caddy automatic HTTPS for a configured domain.
5. WebSocket forwarding for LiveView and Channels.
6. Explicit request-body limits.
7. A health endpoint suitable for container and proxy checks.
8. Runtime environment documentation.
9. Migration, backup, restore, and rollback procedures.

Actual VPS provisioning, DNS changes, secret installation, and deployment execution are not part of this PRD.

### Required Runtime Configuration

- Public host and URL scheme.
- Phoenix secret key base.
- Gateway HMAC signing secret.
- SQLite database path.
- Caddy domain/email configuration as needed.
- Server and pool tuning values where environment-specific.

### Observability

1. Logs include request identifiers and normalized payment/event identifiers.
2. Secrets, overlay URLs, passwords, signatures, and raw webhook bodies are never logged.
3. Webhook rejection reasons are observable through stable reason codes.
4. The health endpoint checks application availability without exposing private state.
5. A web admin or moderation console is excluded.

## Testing Decisions

### Testing Principles

1. Tests verify behavior through public interfaces rather than private function shape.
2. Development proceeds in vertical red-green-refactor slices.
3. Domain tests use real Ecto sandbox transactions rather than mocking the repository.
4. Realtime tests assert externally visible messages or rendered behavior rather than PubSub implementation details.
5. Browser tests cover only critical cross-layer journeys.

### ExUnit Coverage

ExUnit must cover:

1. Registration, login, logout, and creator route isolation.
2. Recipient-key and overlay-token uniqueness and rotation.
3. HMAC signature validation, timestamp freshness, malformed payloads, and body limits.
4. Amount, name, and message validation.
5. Direct pending, paid, and failed creation.
6. Pending-to-paid and pending-to-failed transitions.
7. Rejection of terminal-state regression.
8. Duplicate event idempotency.
9. Conflicting immutable payment data.
10. Exactly-one paid alert behavior.
11. Revenue exclusion for pending and failed payments.
12. Asia/Jakarta day boundaries and 30-day aggregation.
13. Cursor pagination and status filtering.
14. Alert settings validation and threshold eligibility.
15. Fresh-overlay baseline behavior.
16. Ten-minute and 50-alert reconnect catch-up limits.
17. Creator-scoped Channel authorization and notifications.
18. Dashboard test donation behavior.

### Vitest Coverage

Vitest must cover:

1. Indonesian rupiah and date formatting.
2. API error handling.
3. Channel update reconciliation.
4. Revenue-series shaping for the native SVG chart.
5. Payment status presentation.
6. Alert-settings form validation.
7. Onboarding state transitions.

### Playwright Coverage

Playwright must cover:

1. Creator registration and login through LiveView.
2. Authenticated Vue dashboard loading.
3. The fixed test donation updating overview and history.
4. A second browser page using the overlay URL receiving the alert.
5. Alert-setting changes affecting later alerts.
6. Overlay-token rotation invalidating the old URL.
7. Mobile dashboard navigation at one representative viewport.

### Continuous Integration

GitHub Actions runs:

1. Formatting checks.
2. Elixir compilation with warnings treated as errors.
3. ExUnit.
4. TypeScript and Vue checks.
5. Vitest.
6. Production asset build.
7. Playwright with the test SQLite database.

Equivalent local check commands must be documented and compose cleanly into one full verification command.

## Acceptance Criteria

1. Given a new visitor, when they register valid credentials, then they enter their own authenticated Sorak workspace.
2. Given two creators, when either loads dashboard data, then no data owned by the other creator is exposed.
3. Given a correctly signed pending event, when the webhook is processed, then one pending payment and one immutable event exist and no alert is sent.
4. Given that pending payment, when a correctly signed paid event arrives, then the payment becomes paid, revenue changes, and one alert is sent.
5. Given the same paid event is retried, when it is processed again, then the response is idempotent and revenue and alerts do not duplicate.
6. Given a paid or failed payment, when a later event requests another status, then the transition is rejected and current state remains unchanged.
7. Given an invalid signature or stale timestamp, when a webhook is submitted, then no payment or event is stored.
8. Given a donation outside the allowed amount or text limits, when submitted, then validation fails and nothing is broadcast.
9. Given pending, paid, and failed payments, when the dashboard loads, then all appear in history but only paid amounts appear in analytics.
10. Given a logged-in creator, when a new event is accepted, then their Vue dashboard updates through an authenticated Channel without a page refresh.
11. Given multiple overlays connected with the same valid token, when an eligible paid transition commits, then each client queues one alert.
12. Given several live paid transitions, when alerts arrive faster than their duration, then each displays sequentially without overlap.
13. Given an overlay reconnects with a saved cursor, when eligible alerts were missed in the last 10 minutes, then no more than 50 are replayed in order.
14. Given an overlay opens without a saved cursor, when older paid donations exist, then none are replayed.
15. Given a creator rotates the overlay token, when the old URL is opened again, then access is denied.
16. Given a creator changes threshold, duration, color, or sound, when a later eligible donation is paid, then the saved settings govern its alert.
17. Given a creator sends the fixed dashboard test donation, then it is paid, persisted, counted in revenue, and displayed by connected overlays.
18. Given a production configuration and persistent volume, when the Compose stack starts and migrations run, then Caddy serves Sorak over HTTPS and realtime connections work.
19. Given a live SQLite database, when the documented backup and restore procedures are followed, then the restored application retains creator, payment, event, and settings data.

## Out of Scope

- Real payment-provider integration.
- Public donor checkout or donation page.
- Refunds, disputes, fees, balances, withdrawals, and payouts.
- Donor contact information.
- Public creator profiles or directory.
- Public REST API, API keys, or third-party creator integrations.
- Followers, subscriptions, chat, stream sessions, or generic custom events.
- Multi-currency or multi-locale UI.
- Email verification and password-reset delivery.
- OAuth and social login.
- Organizations, teams, and role management.
- Account deletion.
- Creator avatars and social links.
- Multiple named overlays or scene-specific configurations.
- Drag-and-drop overlay positioning.
- Custom CSS.
- Image, video, or audio uploads.
- Text-to-speech.
- Multiple alert themes.
- Automated profanity filtering.
- Creator message-hiding controls.
- Editing or deleting payment history.
- Search, custom analytics ranges, comparisons, and CSV export.
- Platform-admin and moderation interfaces.
- Horizontal Phoenix scaling.
- Remote VPS provisioning or deployment.

## Implementation Constraints

1. The current repository root becomes the Sorak application when implementation begins.
2. The existing pinned Elixir 1.20, Erlang/OTP 27, and Node 22 toolchain should be retained where compatible.
3. Phoenix, LiveView, Vue 3, TypeScript, Vite, Tailwind CSS v4, Ecto, and SQLite are the required stack.
4. The dashboard should avoid a general component library and unnecessary runtime dependencies.
5. The dashboard chart should use native SVG.
6. The overlay sound should not depend on a copyrighted third-party asset.
7. The system must remain operable as one application instance with one persistent SQLite volume.

## Recommended Delivery Slices

These slices are planning guidance, not authorization to implement:

1. Application scaffold, SQLite configuration, and creator authentication.
2. Payment domain with signed webhook and lifecycle tests.
3. Analytics queries and authenticated dashboard API.
4. Vue shell, overview, and event history.
5. Alert settings, overlay LiveView, queue, and reconnect cursor.
6. Dashboard Channel updates and fixed test donation.
7. Onboarding and account controls.
8. Playwright journeys and visual verification.
9. Production image, Compose, Caddy, health, backup/restore, and CI.

Each slice should be completed as a vertical red-green-refactor cycle and independently verified before the next slice begins.

## Further Notes

- The product name "Sorak" is provisional. Domain and trademark availability have not been checked.
- The MVP intentionally treats the dashboard test donation as normal revenue because that behavior was explicitly chosen.
- SQLite is suitable for this agreed single-node MVP. Moving to multiple Phoenix instances requires revisiting persistence, PubSub distribution, migrations, and backup architecture.
- No implementation work is authorized by this document alone.
