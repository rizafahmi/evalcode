defmodule AlurWeb.Router do
  use AlurWeb, :router

  import AlurWeb.AccountAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AlurWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Account-scoped JSON that authenticates with the same browser session
  # cookie the HTML pages use (`fetch` with credentials). Unauthenticated
  # requests get a 401 from `require_api_account`.
  pipeline :api_authenticated do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :fetch_current_scope
    plug :require_api_account
  end

  # Public account routes: registration and sign in. Logged-in accounts are
  # sent back to the pipeline instead.
  scope "/accounts", AlurWeb do
    pipe_through [:browser, :redirect_if_account_is_authenticated]

    get "/register", AccountRegistrationController, :new
    post "/register", AccountRegistrationController, :create
    get "/log-in", AccountSessionController, :new
    post "/log-in", AccountSessionController, :create
  end

  scope "/accounts", AlurWeb do
    pipe_through :browser

    delete "/log-out", AccountSessionController, :delete
  end

  # The signed-in application. Logged-out visitors are redirected to the
  # sign-in page by the live_session on_mount hook.
  #
  # GET /app is a plain authenticated controller page (not a LiveView, not
  # inside the :authenticated live_session). It is where the Vue app mounts
  # (milestone 7 scaffold; milestone 8 Kanban). It reuses the browser session
  # so the Vue fetch calls authenticate with session cookies.
  scope "/", AlurWeb do
    pipe_through [:browser, :require_authenticated_account]

    get "/app", AppController, :index
  end

  scope "/", AlurWeb do
    pipe_through :browser

    live_session :authenticated,
      on_mount: [{AlurWeb.AccountAuth, :require_authenticated}] do
      live "/", PipelineLive, :index
      live "/contacts", ContactsLive, :index
      live "/contacts/new", ContactsLive, :new
      live "/contacts/:id", ContactsLive, :show
      live "/contacts/:id/edit", ContactsLive, :edit
      live "/contacts/:contact_id/deals/new", DealsLive, :new
      live "/deals/:id", DealsLive, :show
      live "/deals/:id/edit", DealsLive, :edit
      live "/todos", TodosLive, :index
    end
  end

  # Public JSON API. Health is unauthenticated. Account-scoped deal endpoints
  # (milestone 8) live in their own `/api` scope below and authenticate with
  # the browser session cookie, answering 401 when nobody is signed in.
  scope "/api", AlurWeb do
    pipe_through :api

    get "/health", HealthController, :index
  end

  scope "/api", AlurWeb do
    pipe_through :api_authenticated

    get "/pipeline", Api.DealsController, :pipeline
    get "/deals", Api.DealsController, :index
    get "/deals/:id", Api.DealsController, :show
    patch "/deals/:id", Api.DealsController, :update
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:alur, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: AlurWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
