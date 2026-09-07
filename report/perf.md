# Alur held-out perf probe

Generated: 2026-09-07T02:31:08.855Z
Base URL: http://127.0.0.1:4000
Wall time: 6.1s

Observational only — numbers are not pass/fail gates. readyMs is the primary signal (time until the accessible ready locator).

| Scenario | Status | n | ready (median) | TTFB | LCP | DCL | Load | Doc bytes | JS+CSS bytes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cold-home | ok | 3 | 44ms | 13ms | 36ms | 23ms | 37ms | 4.6KB | -743B |
| cold-app | ok | 3 | 44ms | 12ms | 36ms | 22ms | 36ms | 3.2KB | -743B |
| nav-contacts | ok | 3 | 47ms | — | — | — | — | — | — |
| deal-open | ok | 3 | 25ms | — | — | — | — | — | — |

## Notes

- Auth/register time is excluded; measurement starts after ensureLoggedIn.
- Nav Timing / LCP apply to full document navigations (`cold-home`, `cold-app`); LiveView clicks often only report readyMs.
- Three samples per scenario; table shows medians. Localhost jitter is expected.
