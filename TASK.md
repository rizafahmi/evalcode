# Sorak MVP Tasks

Source: `PRD.md`

These tasks are atomic vertical slices. Each task delivers one observable behavior and includes its own tests. All tasks are AFK and may be implemented without further product decisions.

A task is not complete until `mix precommit` is green.

Each task ships tests at the cheapest layer that can fail the behavior:

- Domain, webhooks, and LiveView auth: ExUnit through public interfaces (PhoenixTest for LiveView).
- Vue formatting and presentation: Vitest.
- Real-browser Playwright is TASK-47 only.

## TASK-01 — Register a creator and enter the workspace

**Type:** AFK  
**User stories:** 1, 33

### What to build

Let a new creator register through the Bahasa Indonesia LiveView flow and arrive in an authenticated, responsive Vue workspace backed by SQLite.

### Acceptance criteria

- [ ] A visitor can register with a unique email and valid password.
- [ ] Successful registration creates an authenticated creator session.
- [ ] The creator lands in an empty localized dashboard.
- [ ] Invalid or duplicate credentials show safe validation errors.
- [ ] LiveView and database tests cover the complete journey.

### Blocked by

None — can start immediately.

## TASK-02 — Log in as a returning creator

**Type:** AFK  
**User stories:** 2

### What to build

Let an existing creator authenticate through LiveView and return to the Vue workspace.

### Acceptance criteria

- [ ] Valid credentials create a creator session and open the dashboard.
- [ ] Invalid credentials disclose no account-sensitive information.
- [ ] An unauthenticated dashboard request redirects to login.
- [ ] LiveView tests cover success and failure.

### Blocked by

- TASK-01

## TASK-03 — Log out of a creator session

**Type:** AFK  
**User stories:** 2

### What to build

Let an authenticated creator terminate their session from the workspace.

### Acceptance criteria

- [ ] Logout invalidates the active session.
- [ ] The creator returns to the login screen.
- [ ] The former session cannot access authenticated JSON or dashboard routes.
- [ ] LiveView tests cover the complete logout journey.

### Blocked by

- TASK-02

## TASK-04 — Deny cross-creator dashboard access

**Type:** AFK  
**User stories:** 2

### What to build

Enforce creator ownership on every authenticated dashboard read and mutation.

### Acceptance criteria

- [ ] Creator identity is derived from the server-side session.
- [ ] A creator cannot select or infer another creator through request parameters.
- [ ] Cross-creator record access returns a safe denial or not-found response.
- [ ] Integration tests exercise two independent creators.

### Blocked by

- TASK-01

## TASK-05 — Route a signed pending event to its creator

**Type:** AFK  
**User stories:** 16, 35, 36, 37, 40

### What to build

Accept one valid HMAC-signed pending payment event, route it with the public recipient key, persist normalized immutable records, and show it in the owning creator's recent activity.

### Acceptance criteria

- [ ] Registration gives each creator a unique public recipient key.
- [ ] A valid signed pending event creates one payment and one payment event.
- [ ] The pending payment appears only in the owning creator's dashboard.
- [ ] Raw webhook bodies and headers are not retained.
- [ ] Request and dashboard integration tests cover the path.

### Blocked by

- TASK-01

## TASK-06 — Reject an invalid webhook signature

**Type:** AFK  
**User stories:** 38

### What to build

Reject gateway requests whose HMAC signature is missing or invalid.

### Acceptance criteria

- [ ] Signatures are checked against the exact timestamp and raw body.
- [ ] Comparison uses a constant-time operation.
- [ ] Invalid requests persist no payment or event.
- [ ] The response uses a stable rejection code without exposing secrets.

### Blocked by

- TASK-05

## TASK-07 — Reject a stale webhook timestamp

**Type:** AFK  
**User stories:** 38

### What to build

Reject otherwise valid gateway requests outside the five-minute clock-skew window.

### Acceptance criteria

- [ ] Requests older than the allowed window are rejected.
- [ ] Requests too far in the future are rejected.
- [ ] Boundary timestamps inside the window are accepted.
- [ ] Rejected requests persist no payment or event.

### Blocked by

- TASK-05

## TASK-08 — Reject a malformed or oversized webhook payload

**Type:** AFK  
**User stories:** 39

### What to build

Enforce the gateway schema, request-body limit, amount range, and donor text limits before persistence.

### Acceptance criteria

- [ ] Oversized request bodies are rejected.
- [ ] Amounts outside Rp1.000–Rp100.000.000 are rejected.
- [ ] Names over 50 characters and messages over 280 characters are rejected.
- [ ] Missing required or invalid typed fields return stable validation errors.
- [ ] Rejected payloads persist and broadcast nothing.

### Blocked by

- TASK-05

## TASK-09 — Transition a pending payment to paid

**Type:** AFK  
**User stories:** 18, 21, 36

### What to build

Apply a valid paid event to an existing pending payment and expose the committed state in the dashboard.

### Acceptance criteria

- [ ] Pending transitions to paid exactly once.
- [ ] The transition appends an immutable payment event.
- [ ] The payment records its paid timestamp.
- [ ] The dashboard shows the paid status after reload.
- [ ] Tests verify the behavior through the webhook and dashboard interfaces.

### Blocked by

- TASK-05

## TASK-10 — Transition a pending payment to failed

**Type:** AFK  
**User stories:** 18, 21, 36

### What to build

Apply a valid failed event to an existing pending payment and expose the committed state in the dashboard.

### Acceptance criteria

- [ ] Pending transitions to failed exactly once.
- [ ] The transition appends an immutable payment event.
- [ ] Failed payments have no paid timestamp.
- [ ] The dashboard shows the failed status after reload.
- [ ] Tests verify the behavior through the webhook and dashboard interfaces.

### Blocked by

- TASK-05

## TASK-11 — Create a payment directly as paid

**Type:** AFK  
**User stories:** 21, 22, 36

### What to build

Accept a creator's first event for a payment when that event is already paid.

### Acceptance criteria

- [ ] A valid first paid event creates a paid payment.
- [ ] One immutable paid event and paid timestamp are recorded.
- [ ] The payment appears as paid in the creator dashboard.
- [ ] No synthetic pending event is inserted.

### Blocked by

- TASK-05

## TASK-12 — Create a payment directly as failed

**Type:** AFK  
**User stories:** 21, 36

### What to build

Accept a creator's first event for a payment when that event is already failed.

### Acceptance criteria

- [ ] A valid first failed event creates a failed payment.
- [ ] One immutable failed event is recorded.
- [ ] The payment appears as failed in the creator dashboard.
- [ ] No synthetic pending event is inserted.

### Blocked by

- TASK-05

## TASK-13 — Accept a duplicate event idempotently

**Type:** AFK  
**User stories:** 20, 37

### What to build

Let the gateway safely retry an event without duplicating payment state or audit history.

### Acceptance criteria

- [ ] External event identifiers are unique.
- [ ] Retrying the same valid event returns a successful idempotent response.
- [ ] The retry creates no additional payment or payment event.
- [ ] The response identifies the original committed result safely.

### Blocked by

- TASK-05

## TASK-14 — Reject a terminal payment regression

**Type:** AFK  
**User stories:** 19, 20

### What to build

Keep paid and failed payments terminal when a later event requests another state.

### Acceptance criteria

- [ ] A paid payment cannot become pending or failed.
- [ ] A failed payment cannot become pending or paid.
- [ ] Rejected regressions append no accepted transition.
- [ ] The payment's current state and analytics inputs remain unchanged.

### Blocked by

- TASK-09
- TASK-10

## TASK-15 — Reject conflicting immutable payment details

**Type:** AFK  
**User stories:** 20

### What to build

Reject a later event that reuses an external payment identifier with different immutable donation details.

### Acceptance criteria

- [ ] Amount changes are rejected.
- [ ] Conflicting donor identity or message data is rejected.
- [ ] Existing payment and event data remain unchanged.
- [ ] The response uses a stable conflict code.

### Blocked by

- TASK-05

## TASK-16 — Show today's paid revenue

**Type:** AFK  
**User stories:** 11, 21

### What to build

Show the creator's gross paid donation amount for the current Asia/Jakarta calendar day.

### Acceptance criteria

- [ ] Only paid payments contribute.
- [ ] The day boundary uses Asia/Jakarta.
- [ ] The value is formatted as Indonesian rupiah.
- [ ] Pending and failed payments do not affect the value.
- [ ] Tests cover both sides of the timezone boundary.

### Blocked by

- TASK-09

## TASK-17 — Show trailing 30-day paid revenue

**Type:** AFK  
**User stories:** 12, 21

### What to build

Show gross paid donation revenue for the trailing 30 Asia/Jakarta calendar days.

### Acceptance criteria

- [ ] Only paid payments in the 30-day window contribute.
- [ ] The window uses Asia/Jakarta calendar dates.
- [ ] Older, pending, and failed payments are excluded.
- [ ] The value is formatted as Indonesian rupiah.

### Blocked by

- TASK-09

## TASK-18 — Show trailing 30-day paid donation count

**Type:** AFK  
**User stories:** 13, 21

### What to build

Show the number of paid donations in the trailing 30 Asia/Jakarta calendar days.

### Acceptance criteria

- [ ] Each paid payment in the window counts once.
- [ ] Pending, failed, duplicate, and older payments are excluded.
- [ ] The count is scoped to the authenticated creator.
- [ ] Tests cover empty and populated periods.

### Blocked by

- TASK-09

## TASK-19 — Chart daily paid revenue for 30 days

**Type:** AFK  
**User stories:** 14

### What to build

Render a native SVG series of daily gross paid donation totals for the last 30 Asia/Jakarta dates.

### Acceptance criteria

- [ ] The API returns one ordered value for every date, including zero days.
- [ ] Only paid payments contribute.
- [ ] The Vue dashboard renders the series without a charting library.
- [ ] The chart remains readable at desktop and mobile widths.
- [ ] Query, formatting, and component tests cover the behavior.

### Blocked by

- TASK-17

## TASK-20 — Show recent payment activity

**Type:** AFK  
**User stories:** 16

### What to build

Show the creator's latest pending, paid, and failed payments on the dashboard overview.

### Acceptance criteria

- [ ] Recent activity is newest first.
- [ ] Each row shows donor label, amount, status, and timestamp.
- [ ] Missing donor names display as "Anonim".
- [ ] Text renders as escaped plain text.
- [ ] Only the authenticated creator's payments appear.

### Blocked by

- TASK-05
- TASK-09
- TASK-10

## TASK-21 — Update payment activity through a creator Channel

**Type:** AFK  
**User stories:** 15, 16

### What to build

Push accepted payment changes to the owning creator's Vue recent-activity view without a page refresh.

### Acceptance criteria

- [ ] Channel authorization derives identity from the creator session.
- [ ] Accepted creates and transitions update recent activity.
- [ ] Another creator cannot join or receive the topic.
- [ ] Reconnect reconciles activity from the REST source.
- [ ] Channel and component tests cover the path.

### Blocked by

- TASK-20

## TASK-22 — Update revenue cards through a creator Channel

**Type:** AFK  
**User stories:** 15

### What to build

Refresh the creator's revenue cards when a paid transition arrives through the authenticated Channel.

### Acceptance criteria

- [ ] A paid transition updates affected totals without reload.
- [ ] Pending and failed events leave totals unchanged.
- [ ] Duplicate events do not increment totals twice.
- [ ] Reconnect restores authoritative REST values.

### Blocked by

- TASK-16
- TASK-17
- TASK-18
- TASK-21

## TASK-23 — Update the revenue chart through a creator Channel

**Type:** AFK  
**User stories:** 15

### What to build

Refresh the relevant daily chart value when a paid transition arrives.

### Acceptance criteria

- [ ] A paid transition updates the correct Asia/Jakarta date.
- [ ] Pending and failed events do not change the series.
- [ ] Duplicate events do not change the series twice.
- [ ] Reconnect replaces local chart state with authoritative REST data.

### Blocked by

- TASK-19
- TASK-21

## TASK-24 — Open an overlay with a secret creator URL

**Type:** AFK  
**User stories:** 5, 6, 34

### What to build

Give each creator one high-entropy overlay URL that opens a transparent, scalable LiveView without an authenticated creator session.

### Acceptance criteria

- [ ] Each creator has one unique secret overlay credential.
- [ ] A valid URL opens the transparent overlay.
- [ ] An invalid token reveals no creator information.
- [ ] The creator can copy the URL from the dashboard.
- [ ] The layout scales safely across 16:9 resolutions.

### Blocked by

- TASK-01

## TASK-25 — Render one alert for a paid transition

**Type:** AFK  
**User stories:** 22, 32

### What to build

Publish a committed paid transition to the creator's overlay and render one localized top-center alert.

### Acceptance criteria

- [ ] Broadcast happens only after the database transaction commits.
- [ ] The alert shows escaped donor label, rupiah amount, and message.
- [ ] One paid transition produces one alert.
- [ ] Direct-paid creation and pending-to-paid transition both work.
- [ ] LiveView tests cover rendering and topic isolation.

### Blocked by

- TASK-09
- TASK-11
- TASK-24

## TASK-26 — Suppress alerts for non-paid states

**Type:** AFK  
**User stories:** 21, 22

### What to build

Keep pending and failed payment events out of connected overlays.

### Acceptance criteria

- [ ] Pending creation emits no overlay alert.
- [ ] Pending-to-failed emits no overlay alert.
- [ ] Direct-failed creation emits no overlay alert.
- [ ] The events remain visible in dashboard history.

### Blocked by

- TASK-10
- TASK-25

## TASK-27 — Suppress duplicate alerts for retried paid events

**Type:** AFK  
**User stories:** 22

### What to build

Prevent an idempotent retry of a paid event from publishing another overlay alert.

### Acceptance criteria

- [ ] The first paid event publishes one alert.
- [ ] Retrying the same event publishes no additional alert.
- [ ] The result survives application process restarts.
- [ ] Integration tests observe the external PubSub or LiveView behavior.

### Blocked by

- TASK-13
- TASK-25

## TASK-28 — Deliver an alert to every connected overlay

**Type:** AFK  
**User stories:** 23

### What to build

Let multiple browser or OBS clients using the same valid creator URL receive the same paid alert.

### Acceptance criteria

- [ ] Two connected clients each receive one alert.
- [ ] Client playback state is independent.
- [ ] Disconnecting one client does not affect another.
- [ ] No client receives another creator's alert.

### Blocked by

- TASK-25

## TASK-29 — Queue burst alerts without overlap

**Type:** AFK  
**User stories:** 24

### What to build

Queue paid alerts FIFO when events arrive faster than they can be displayed.

### Acceptance criteria

- [ ] Only one alert is visible at a time.
- [ ] Alerts display in committed sequence order.
- [ ] Every live alert completes reveal, hold, and exit before the next.
- [ ] Reduced-motion mode preserves ordering without disruptive animation.

### Blocked by

- TASK-25

## TASK-30 — Start a fresh overlay without replaying history

**Type:** AFK  
**User stories:** 27

### What to build

Establish the current payment-event sequence as the baseline when an overlay has no saved cursor.

### Acceptance criteria

- [ ] Existing paid history is not replayed on first open.
- [ ] A paid transition committed after connection is displayed.
- [ ] Subscription and baseline establishment do not leave an event-loss race.
- [ ] Tests cover history before, during, and after connection.

### Blocked by

- TASK-24
- TASK-25

## TASK-31 — Recover missed alerts from a saved cursor

**Type:** AFK  
**User stories:** 25

### What to build

Use a browser-local last-displayed sequence to replay eligible alerts missed during a reconnect.

### Acceptance criteria

- [ ] The cursor advances only after an alert displays.
- [ ] Events after the saved cursor replay in sequence order.
- [ ] Replayed events join the same FIFO queue as live events.
- [ ] A disconnect during playback does not silently skip that alert.

### Blocked by

- TASK-29
- TASK-30

## TASK-32 — Skip reconnect alerts older than 10 minutes

**Type:** AFK  
**User stories:** 25, 26

### What to build

Exclude missed paid alerts older than 10 minutes when reconnecting an existing overlay.

### Acceptance criteria

- [ ] Eligible events inside the window replay.
- [ ] Older events do not replay.
- [ ] The cursor advances past skipped stale events.
- [ ] Boundary timestamps are deterministic in tests.

### Blocked by

- TASK-31

## TASK-33 — Cap reconnect catch-up at 50 alerts

**Type:** AFK  
**User stories:** 25, 26

### What to build

Limit a reconnect catch-up batch to the newest 50 eligible alerts.

### Acceptance criteria

- [ ] At most 50 missed alerts are queued.
- [ ] The selected alerts preserve ascending sequence order.
- [ ] Skipped older events cannot replay on the next reconnect.
- [ ] Live events received after connection are not subject to this cap.

### Blocked by

- TASK-31

## TASK-34 — Change the overlay accent color

**Type:** AFK  
**User stories:** 28

### What to build

Let a creator save a valid accent color and use it for later overlay alerts.

### Acceptance criteria

- [ ] The dashboard shows the current saved color.
- [ ] A valid update persists for the authenticated creator.
- [ ] Invalid color input is rejected.
- [ ] A later alert renders with the saved color.

### Blocked by

- TASK-25

## TASK-35 — Change alert display duration

**Type:** AFK  
**User stories:** 29

### What to build

Let a creator save alert duration and apply it to subsequent FIFO playback.

### Acceptance criteria

- [ ] The default duration is six seconds.
- [ ] Valid duration changes persist.
- [ ] Invalid duration values are rejected.
- [ ] Later alerts hold for the saved duration before the queue advances.

### Blocked by

- TASK-29

## TASK-36 — Set a minimum alert amount

**Type:** AFK  
**User stories:** 30

### What to build

Let a creator save a minimum paid donation amount required for overlay display.

### Acceptance criteria

- [ ] The default threshold accepts every valid donation amount.
- [ ] Paid donations below the saved threshold do not alert.
- [ ] Paid donations at or above the threshold alert.
- [ ] Suppressed payments remain in history and revenue analytics.

### Blocked by

- TASK-25

## TASK-37 — Toggle the bundled alert sound

**Type:** AFK  
**User stories:** 31

### What to build

Let a creator enable or disable the original bundled alert sound for later alerts.

### Acceptance criteria

- [ ] Sound is enabled by default.
- [ ] The saved toggle is creator-specific.
- [ ] Enabled alerts request one sound playback.
- [ ] Disabled alerts request no sound playback.
- [ ] The sound has no third-party licensing dependency.

### Blocked by

- TASK-25

## TASK-38 — Page through payment history

**Type:** AFK  
**User stories:** 17

### What to build

Let a creator browse immutable payment history using stable cursor pagination.

### Acceptance criteria

- [ ] Results are deterministic and newest first.
- [ ] Following a cursor returns the next page without overlap.
- [ ] New inserts do not corrupt an existing pagination walk.
- [ ] Only the authenticated creator's records appear.
- [ ] The Vue history view exposes next-page loading states.

### Blocked by

- TASK-20

## TASK-39 — Filter payment history by status

**Type:** AFK  
**User stories:** 18

### What to build

Let a creator filter paginated payment history by pending, paid, or failed current status.

### Acceptance criteria

- [ ] Each valid status returns only matching payments.
- [ ] Changing filters resets pagination.
- [ ] Invalid status values return a stable validation error.
- [ ] Empty filtered results have a localized empty state.

### Blocked by

- TASK-38

## TASK-40 — Inspect a payment's transition audit

**Type:** AFK  
**User stories:** 19, 20

### What to build

Show one payment's immutable normalized details and ordered accepted transition history.

### Acceptance criteria

- [ ] The detail view shows payment identity, donation data, and current status.
- [ ] Accepted events appear in local sequence order.
- [ ] Raw webhook data and secrets are absent.
- [ ] Another creator cannot inspect the payment.
- [ ] No edit or delete action is offered.

### Blocked by

- TASK-09
- TASK-38

## TASK-41 — Send the fixed normal-revenue test donation

**Type:** AFK  
**User stories:** 9, 10

### What to build

Let an authenticated creator create the fixed localized paid sample through the shared payment ingestion domain.

### Acceptance criteria

- [ ] The browser never receives the gateway signing secret.
- [ ] The test action creates a normal immutable paid payment.
- [ ] The payment contributes to today's and 30-day revenue.
- [ ] Connected overlays display the alert.
- [ ] Repeated button uses create distinct normal payments.

### Blocked by

- TASK-16
- TASK-25

## TASK-42 — Complete the OBS onboarding checklist

**Type:** AFK  
**User stories:** 8

### What to build

Guide a new creator through copying the overlay URL, adding a 1920×1080 OBS Browser Source, and sending the test donation.

### Acceptance criteria

- [ ] New creators see the three-step Bahasa Indonesia checklist.
- [ ] Overlay URL and OBS setup instructions are available in context.
- [ ] Successful test-donation creation completes onboarding.
- [ ] Static setup instructions remain accessible after completion.

### Blocked by

- TASK-24
- TASK-41

## TASK-43 — Change a creator display name

**Type:** AFK  
**User stories:** 3

### What to build

Let an authenticated creator update the display name used in their workspace.

### Acceptance criteria

- [ ] The dashboard shows the current display name.
- [ ] A valid update persists for the authenticated creator.
- [ ] Invalid length or blank input is rejected.
- [ ] Updating one creator cannot affect another.

### Blocked by

- TASK-01

## TASK-44 — Change a creator password

**Type:** AFK  
**User stories:** 4

### What to build

Let an authenticated creator replace their password after proving knowledge of the current password.

### Acceptance criteria

- [ ] The correct current password is required.
- [ ] The new password must satisfy registration rules.
- [ ] The old password no longer authenticates after success.
- [ ] The new password authenticates successfully.
- [ ] Errors disclose no password-sensitive information.

### Blocked by

- TASK-02

## TASK-45 — Rotate and revoke an overlay URL

**Type:** AFK  
**User stories:** 7

### What to build

Let an authenticated creator replace the secret overlay credential and immediately revoke the old URL.

### Acceptance criteria

- [ ] Rotation requires an authenticated creator mutation.
- [ ] The new URL opens the creator overlay.
- [ ] The old URL cannot establish a new overlay session.
- [ ] Rotation affects no other creator.
- [ ] The credential is not exposed in normal application logs.

### Blocked by

- TASK-24

## TASK-46 — Run project verification in GitHub Actions

**Type:** AFK  
**User stories:** 43

### What to build

Run the repository's non-browser verification command in GitHub Actions with the same behavior available locally.

### Acceptance criteria

- [ ] CI checks formatting and compiles Elixir with warnings as errors.
- [ ] CI runs ExUnit, TypeScript checks, Vitest, and the production asset build.
- [ ] One documented local command runs the equivalent checks.
- [ ] Dependency caches do not hide lockfile or compile failures.
- [ ] The workflow contains no deployment credentials.

### Blocked by

- TASK-23
- TASK-28
- TASK-32
- TASK-33
- TASK-34
- TASK-35
- TASK-36
- TASK-37
- TASK-39
- TASK-40
- TASK-42
- TASK-43
- TASK-44
- TASK-45

## TASK-47 — Run critical creator and overlay journeys in Playwright

**Type:** AFK  
**User stories:** 43

### What to build

Exercise the approved creator, dashboard, and overlay journeys in a real browser locally and in GitHub Actions.

### Acceptance criteria

- [ ] A browser test registers and enters the Vue workspace.
- [ ] A second page using the overlay URL receives the fixed test alert.
- [ ] Setting changes affect a later alert.
- [ ] Overlay-token rotation invalidates the old URL.
- [ ] One mobile viewport verifies dashboard navigation.
- [ ] Playwright runs in CI after non-browser checks.

### Blocked by

- TASK-46

## TASK-48 — Build a production Sorak container image

**Type:** AFK  
**User stories:** 41

### What to build

Build a minimal multi-stage production image containing the Phoenix release and compiled Vue assets.

### Acceptance criteria

- [ ] The image uses the pinned compatible Elixir, OTP, and Node toolchain.
- [ ] Frontend assets are compiled during the build.
- [ ] Build-only tools and source caches are absent from the runtime stage.
- [ ] The release starts with runtime environment configuration.
- [ ] An image smoke test reaches the application.

### Blocked by

- TASK-47

## TASK-49 — Serve Sorak over HTTPS with Compose and Caddy

**Type:** AFK  
**User stories:** 41

### What to build

Run Sorak and Caddy as a single-node Compose stack with automatic HTTPS, WebSocket forwarding, migrations, and persistent SQLite storage.

### Acceptance criteria

- [ ] Phoenix is private to the Compose network.
- [ ] Caddy serves the configured public host over HTTPS.
- [ ] LiveView and Channel WebSockets work through Caddy.
- [ ] SQLite data survives application-container replacement.
- [ ] Migrations run as an explicit release operation.
- [ ] Required runtime variables are documented.

### Blocked by

- TASK-48

## TASK-50 — Expose a production health check

**Type:** AFK  
**User stories:** 41

### What to build

Expose a safe health endpoint and use it for application and proxy availability checks.

### Acceptance criteria

- [ ] The endpoint returns success when the application is available.
- [ ] It exposes no creator, payment, configuration, or secret data.
- [ ] The production container defines a health check.
- [ ] Compose startup and Caddy routing use health state appropriately.

### Blocked by

- TASK-49

## TASK-51 — Back up the live SQLite database safely

**Type:** AFK  
**User stories:** 42

### What to build

Provide and document an online SQLite backup procedure suitable for the production volume.

### Acceptance criteria

- [ ] Backup uses SQLite's online backup mechanism.
- [ ] The procedure does not copy a live database file directly.
- [ ] Output location, permissions, and retention responsibilities are documented.
- [ ] A verification step confirms the backup can be opened.
- [ ] Secrets are not included in backup logs.

### Blocked by

- TASK-49

## TASK-52 — Restore and verify a SQLite backup

**Type:** AFK  
**User stories:** 42

### What to build

Provide and document a safe restore procedure that proves creator, payment, event, and settings data survive recovery.

### Acceptance criteria

- [ ] The procedure coordinates application writes before replacement.
- [ ] The restored database passes integrity checking and migrations.
- [ ] Sorak starts against the restored database.
- [ ] A verification checklist confirms representative creator and donation data.
- [ ] Rollback instructions preserve the pre-restore database.

### Blocked by

- TASK-51
