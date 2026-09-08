# Alur held-out perf probe

Generated: 2026-09-08T22:43:07.255Z
Base URL: http://127.0.0.1:4000
Wall time: 36.0s

Observational only — numbers are not pass/fail gates. readyMs is the primary signal (time until the accessible ready locator).

| Scenario | Status | n | ready (median) | TTFB | LCP | DCL | Load | Doc bytes | JS+CSS bytes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cold-home | ok | 3 | 40ms | 12ms | 32ms | 22ms | 38ms | 4.4KB | -743B |

## Notes

- Auth/register time is excluded; measurement starts after ensureLoggedIn.
- Nav Timing / LCP apply to full document navigations (`cold-home`, `cold-app`); LiveView clicks often only report readyMs.
- Three samples per scenario; table shows medians. Localhost jitter is expected.
