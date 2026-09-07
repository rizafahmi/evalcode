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
    plug :accepts, ["json"]
    plug :fetch_session
    plug :fetch_current_scope_for_user
    plug :require_authenticated_api_user
  end

  scope "/api", AlurWeb do
    pipe_through :api

    get "/health", HealthController, :index
  end

  scope "/api", AlurWeb do
    pipe_through :api_authenticated

    get "/deals", DealController, :index
    get "/deals/:id", DealController, :show
    patch "/deals/:id", DealController, :update
    put "/deals/:id", DealController, :update
    get "/pipeline", PipelineController, :index
  end

  ## Authenticated routes

  scope "/", AlurWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/app", AppController, :index

    live_session :require_authenticated_user,
      on_mount: [{AlurWeb.UserAuth, :require_authenticated}] do
      live "/", PipelineLive, :index
      live "/contacts", ContactLive.Index, :index
      live "/contacts/new", ContactLive.Form, :new
      live "/contacts/:id", ContactLive.Show, :show
      live "/contacts/:id/edit", ContactLive.Form, :edit
      live "/contacts/:contact_id/deals/new", DealLive.Form, :new

      live "/deals/new", DealLive.Form, :new
      live "/deals/:id", DealLive.Show, :show
      live "/deals/:id/edit", DealLive.Form, :edit
      live "/todos", TodoLive, :index
      live "/to-dos", TodoLive, :index

      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", AlurWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{AlurWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:alur, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: AlurWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
