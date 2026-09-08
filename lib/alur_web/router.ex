defmodule AlurWeb.Router do
  use AlurWeb, :router

  import AlurWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AlurWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :api_authenticated do
    plug :api
    plug :fetch_session
    plug :fetch_current_scope_for_user
    plug :require_api_authenticated_user
  end

  # Other scopes may use custom stacks.
  scope "/api", AlurWeb do
    pipe_through :api

    get "/health", Api.HealthController, :show
  end

  scope "/api", AlurWeb do
    pipe_through :api_authenticated

    get "/deals", Api.DealController, :index
    get "/deals/:id", Api.DealController, :show
    patch "/deals/:id", Api.DealController, :update
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

  ## Authentication routes

  scope "/", AlurWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{AlurWeb.UserAuth, :require_authenticated}] do
      live "/", PipelineLive, :index
      live "/contacts", ContactsLive, :index
      live "/contacts/new", ContactsLive, :new
      live "/contacts/:id", ContactsLive, :show
      live "/contacts/:id/edit", ContactsLive, :edit
      live "/contacts/:contact_id/deals/new", DealsLive, :new
      live "/deals/:id", DealsLive, :show
      live "/deals/:id/edit", DealsLive, :edit
      live "/todos", TodosLive, :index
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    post "/users/update-password", UserSessionController, :update_password
    get "/app", PageController, :app
  end

  scope "/", AlurWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{AlurWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
