# Alur held-out milestone score

Generated: 2026-09-08T22:39:22.530Z
Base URL: http://127.0.0.1:4000
Wall time: 92.6s

| Milestone | Bullet | Status | Duration |
| --- | --- | --- | --- |
| M1 | M1 create an account, log in, see nav, open three sections, log out | pass | 5.1s |
| M1 | M1 logged-out visit cannot see the app | pass | 0.6s |
| M2 | M2 add, find by name, open, edit, delete contact | pass | 5.2s |
| M2 | M2 another account does not see that contact | pass | 9.1s |
| M3 | M3 create deal with IDR, open, format, change column, list on contact, delete | pass | 5.6s |
| M4 | M4 deals on board, drag Lead→Meeting persists, totals, click opens deal | pass | 5.4s |
| M5 | M5 created line, move line with timestamp, note, no edit/delete | pass | 5.3s |
| M6 | M6 add follow-up, see on To-dos with deal name, overdue, mark done, activity lines | pass | 5.5s |
| M7 | M7 GET /api/health returns {status:ok} | pass | 0.0s |
| M7 | M7 signed-in /app is a mounted Vue app | fail | 19.5s |
| M7 | M7 mix test and Vitest both pass | skip | 0.0s |
| M8 | M8 unauthenticated /api/deals* returns 401 | pass | 0.1s |
| M8 | M8 signed-in GET/PATCH /api/deals persists move; other account isolated | pass | 10.1s |
| M8 | M8 /app Vue board drag via /api, totals, click opens LiveView deal | fail | 20.1s |

## Summary

- pass: 11
- fail: 2
- skip: 1

## Failures

- **M7** M7 signed-in /app is a mounted Vue app
  - Error: [2mexpect([22m[31mlocator[39m[2m).[22mtoBeVisible[2m([22m[2m)[22m failed
- **M8** M8 /app Vue board drag via /api, totals, click opens LiveView deal
  - Error: [2mexpect([22m[31mlocator[39m[2m).[22mtoBeVisible[2m([22m[2m)[22m failed
