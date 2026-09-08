status: failed

## What's new in the app

- Added an unauthenticated `/api/health` endpoint that reports `{"status":"ok"}`.
- Added an authenticated `/app` controller page with a Vue mount point.
- Added a Vue scaffold that displays the workspace and API health state when its frontend dependencies are installed.

## What was built

- Added `AlurWeb.Api.HealthController` and `GET /api/health` under the existing JSON API pipeline.
- Added authenticated controller route `GET /app` alongside the existing authenticated routes; it is intentionally outside all LiveView sessions.
- Added `page_html/app.html.heex` with the empty `#vue-app` mount node wrapped in `Layouts.app`.
- Added `assets/vue/main.ts`, `assets/vite.config.ts`, `assets/package.json`, and a Vitest test for the Vue scaffold.
- Imported the TypeScript Vue entry from `assets/js/app.js` so the existing Phoenix esbuild output serves it without changing `PipelineLive` or adding navigation.
- Added ConnCase coverage for health, authentication, and the `/app` mount node.

## Decisions not in the PRD

- The Vue scaffold uses a TypeScript `defineComponent` render function rather than a `.vue` single-file component. This keeps it directly compatible with the existing esbuild entry while retaining Vite/Vitest for the frontend toolchain.
- The health request uses same-origin credentials so the scaffold is ready for the session-cookie API behavior planned for milestone 8.

## Notes for the next milestone

- Install frontend dependencies in `assets/` before running Vitest or the Phoenix asset build. Then verify the signed-in `/app` page in a browser and replace the stub with the milestone 8 Kanban.
- Keep `/` owned by `PipelineLive`; `/app` is the Vue surface for later REST work.

## Deviations

- The required Vitest and browser verification could not be completed in this sandbox. `npm install --prefix assets` could not reach `registry.npmjs.org` (`ENOTFOUND`), and the available npm cache lacked the registry metadata required for offline resolution. Consequently, `mix assets.build` also cannot resolve the `vue` package.
- No later-milestone API or Kanban work was started.

## Verification

- `mix precommit` passed: 132 tests, formatter, Credo, Dialyzer, ExDNA, and Reach.
- Focused controller tests passed, including exact JSON health output and authenticated `/app` behavior.
- `npm --prefix assets test` was attempted but could not start because `vitest` was unavailable after the blocked dependency installation.
- `mix assets.build` was attempted and failed only because the uninstalled `vue` npm package cannot be resolved.
