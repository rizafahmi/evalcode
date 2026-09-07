# Alur held-out perf probe

Generated: 2026-09-06T15:42:19.444Z
Base URL: http://127.0.0.1:4000
Wall time: 5.4s

Observational only — numbers are not pass/fail gates. readyMs is the primary signal (time until the accessible ready locator).

| Scenario | Status | n | ready (median) | TTFB | LCP | DCL | Load | Doc bytes | JS+CSS bytes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cold-home | ok | 3 | 43ms | 12ms | 36ms | 21ms | 35ms | 4.6KB | -743B |
| cold-app | ok | 3 | 38ms | 12ms | 32ms | 22ms | 34ms | 3.4KB | -743B |
| nav-contacts | ok | 3 | 49ms | — | — | — | — | — | — |
| deal-open | ok | 3 | 47ms | — | — | — | — | — | — |

## Notes

- Auth/register time is excluded; measurement starts after ensureLoggedIn.
- Nav Timing / LCP apply to full document navigations (`cold-home`, `cold-app`); LiveView clicks often only report readyMs.
- Three samples per scenario; table shows medians. Localhost jitter is expected.
