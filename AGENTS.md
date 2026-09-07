This is a web application written using the Phoenix web framework.

## Project guidelines

- **Always** use `mix igniter.add <package name>`. Do not add deps manually to `mix.exs`.
- Use `mix precommit` alias when you are done with all changes and fix any pending issues
- Use the already included and available `:req` (`Req`) library for HTTP requests, **avoid** `:httpoison`, `:tesla`, and `:httpc`. Req is included by default and is the preferred HTTP client for Phoenix apps
- Always consult documentation before implementing unfamiliar APIs using `usage_rules`:
  ```sh
  # Search all project dependencies
  mix usage_rules.search_docs "search term"

  # Search specific packages
  mix usage_rules.search_docs "search term" -p ecto -p req

  # Search specific versions
  mix usage_rules.search_docs "search term" -p ecto@3.14.0

  # Search all packages on hex
  mix usage_rules.search_docs "search term" --everywhere

  # Search only in titles / specific functions
  mix usage_rules.search_docs "Enum.zip" --query-by title

  # Inspect local functions and modules
  mix usage_rules.docs Enum.zip/1
  ```

### Phoenix v1.8 guidelines

- **Prefer** PhoenixTest to integration test and end-to-end test inside `test/alur_web/features/` folder. See @docs/phoenix-test.md
- **Always** begin your LiveView templates with `<Layouts.app flash={@flash} ...>` which wraps all inner content. But feel free to redesign the navigation bar, footers, headers etc. to follow the design
- The `AlurWeb.Layouts` module is aliased in the `alur_web.ex` file, so you can use it without needing to alias it again
- Anytime you run into errors with no `current_scope` assign:
  - You failed to follow the Authenticated Routes guidelines, or you failed to pass `current_scope` to `<Layouts.app>`
  - **Always** fix the `current_scope` error by moving your routes to the proper `live_session` and ensure you pass `current_scope` as needed
- Phoenix v1.8 moved the `<.flash_group>` component to the `Layouts` module. You are **forbidden** from calling `<.flash_group>` outside of the `layouts.ex` module
- Out of the box, `core_components.ex` imports an `<.icon name="hero-x-mark" class="w-5 h-5"/>` component for for hero icons. **Always** use the `<.icon>` component for icons, **never** use `Heroicons` modules or similar
- **Always** use the imported `<.input>` component for form inputs from `core_components.ex` when available. `<.input>` is imported and using it will will save steps and prevent errors
- If you override the default input classes (`<.input class="myclass px-2 py-1 rounded-lg">)`) class with your own values, no default classes are inherited, so your
custom classes must fully style the input

### UI & Design System Guidelines (Depot)

- **Always** follow the Depot design specification in `DESIGN.md` when writing or modifying UI components, templates, or styles. Consult the `.agents/skills/depot-design` skill for complete token scales and component specifications.
- **Theme & Aesthetic**: Dark server-rack / developer-console language. Base canvas is Carbon (`#04040b` / `bg-carbon`). Surfaces stack cleanly: Carbon (`#04040b`) → Graphite (`#121113` / `bg-graphite`) → Obsidian (`#1a191b` / `bg-obsidian`) → Slate (`#232225` / `bg-slate`).
- **Hairline Borders**: Separate sections and surfaces with 1px hairline Basalt (`#2b292d` / `border-basalt`) borders rather than spacing alone or drop shadows.
- **No Drop Shadows**: Never apply drop shadows. Use the subtle inset top highlight (`shadow-subtle` / `rgba(255, 255, 255, 0.06) 0px 1px 0px 0px inset`) or hairline borders for surface definition.
- **CTA Discipline**: Signal Green (`#71d083` / `bg-signal-green`) is exclusively reserved for the single primary CTA button fill. Do not use Signal Green for cards, tags, or secondary buttons. Secondary buttons should use ghost/outline styling with Basalt borders.
- **Border Radius**: Use 6px (`rounded-md`) for buttons, inputs, and cards. Use 2px (`rounded-xs`) for tags, badges, and nav items. Never use large rounded radii (12px+) or pill shapes for cards/buttons.
- **Typography & Tracking**:
  - Headings (36px+): Red Hat Display (`font-display`) with negative tracking (`tracking-[-0.025em]`).
  - Body & UI (10-20px): Red Hat Text (`font-text`) with positive tracking (`tracking-[0.025em]`).
  - Code & Status: Red Hat Mono (`font-mono`) for terminal logs, status labels, and code snippets.
  - Text colors: Chalk (`#e5e5e5` / `text-chalk`) for headings, Ash (`#eeeef0` / `text-ash`) for body, Fog (`#7c7a85` / `text-fog`) for muted text. Never use pure white (`#ffffff`).
- **Component Reuse**: Prefer `<.button>`, `<.input>`, and components from `AlurWeb.CoreComponents` rather than writing unstyled raw HTML elements.

<!-- phoenix-gen-auth-start -->
## Authentication

- **Always** handle authentication flow at the router level with proper redirects
- **Always** be mindful of where to place routes. `phx.gen.auth` creates multiple router plugs and `live_session` scopes:
  - A plug `:fetch_current_scope_for_user` that is included in the default browser pipeline
  - A plug `:require_authenticated_user` that redirects to the log in page when the user is not authenticated
  - A `live_session :current_user` scope - for routes that need the current user but don't require authentication, similar to `:fetch_current_scope_for_user`
  - A `live_session :require_authenticated_user` scope - for routes that require authentication, similar to the plug with the same name
  - In both cases, a `@current_scope` is assigned to the Plug connection and LiveView socket
  - A plug `redirect_if_user_is_authenticated` that redirects to a default path in case the user is authenticated - useful for a registration page that should only be shown to unauthenticated users
- **Always let the user know in which router scopes, `live_session`, and pipeline you are placing the route, AND SAY WHY**
- `phx.gen.auth` assigns the `current_scope` assign - it **does not assign a `current_user` assign**
- Always pass the assign `current_scope` to context modules as first argument. When performing queries, use `current_scope.user` to filter the query results
- To derive/access `current_user` in templates, **always use the `@current_scope.user`**, never use **`@current_user`** in templates or LiveViews
- **Never** duplicate `live_session` names. A `live_session :current_user` can only be defined __once__ in the router, so all routes for the `live_session :current_user`  must be grouped in a single block
- Anytime you hit `current_scope` errors or the logged in session isn't displaying the right content, **always double check the router and ensure you are using the correct plug and `live_session` as described below**

### Routes that require authentication

LiveViews that require login should **always be placed inside the __existing__ `live_session :require_authenticated_user` block**:

    scope "/", AppWeb do
      pipe_through [:browser, :require_authenticated_user]

      live_session :require_authenticated_user,
        on_mount: [{AlurWeb.UserAuth, :require_authenticated}] do
        # phx.gen.auth generated routes
        live "/users/settings", UserLive.Settings, :edit
        live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
        # our own routes that require logged in user
        live "/", MyLiveThatRequiresAuth, :index
      end
    end

Controller routes must be placed in a scope that sets the `:require_authenticated_user` plug:

    scope "/", AppWeb do
      pipe_through [:browser, :require_authenticated_user]

      get "/", MyControllerThatRequiresAuth, :index
    end

### Routes that work with or without authentication

LiveViews that can work with or without authentication, **always use the __existing__ `:current_user` scope**, ie:

    scope "/", MyAppWeb do
      pipe_through [:browser]

      live_session :current_user,
        on_mount: [{AlurWeb.UserAuth, :mount_current_scope}] do
        # our own routes that work with or without authentication
        live "/", PublicLive
      end
    end

Controllers automatically have the `current_scope` available if they use the `:browser` pipeline.

<!-- phoenix-gen-auth-end -->

<!-- usage-rules-start -->
<!-- igniter-start -->
## igniter usage
_A code generation and project patching framework_

[igniter usage rules](deps/igniter/usage-rules.md)
<!-- igniter-end -->
<!-- phoenix:ecto-start -->
## phoenix:ecto usage
[phoenix:ecto usage rules](deps/phoenix/usage-rules/ecto.md)
<!-- phoenix:ecto-end -->
<!-- phoenix:elixir-start -->
## phoenix:elixir usage
[phoenix:elixir usage rules](deps/phoenix/usage-rules/elixir.md)
<!-- phoenix:elixir-end -->
<!-- phoenix:html-start -->
## phoenix:html usage
[phoenix:html usage rules](deps/phoenix/usage-rules/html.md)
<!-- phoenix:html-end -->
<!-- phoenix:liveview-start -->
## phoenix:liveview usage
[phoenix:liveview usage rules](deps/phoenix/usage-rules/liveview.md)
<!-- phoenix:liveview-end -->
<!-- phoenix:phoenix-start -->
## phoenix:phoenix usage
[phoenix:phoenix usage rules](deps/phoenix/usage-rules/phoenix.md)
<!-- phoenix:phoenix-end -->
<!-- usage_rules-start -->
## usage_rules usage
_A config-driven dev tool for Elixir projects to manage AGENTS.md files and agent skills from dependencies_

[usage_rules usage rules](deps/usage_rules/usage-rules.md)
<!-- usage_rules-end -->
<!-- usage_rules:elixir-start -->
## usage_rules:elixir usage
[usage_rules:elixir usage rules](deps/usage_rules/usage-rules/elixir.md)
<!-- usage_rules:elixir-end -->
<!-- usage_rules:otp-start -->
## usage_rules:otp usage
[usage_rules:otp usage rules](deps/usage_rules/usage-rules/otp.md)
<!-- usage_rules:otp-end -->
<!-- usage-rules-end -->
