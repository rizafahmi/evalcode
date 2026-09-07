defmodule AlurWeb.AccountAuth do
  @moduledoc """
  Handles signing accounts in and out, and authenticating requests.

  The signed-in state is carried by a database-backed session token stored
  in the plug session, so it works the same way for LiveViews (via the
  `live_session` `on_mount` callbacks below) and for JSON API calls that
  reuse session cookies.

  Every controller-rendered page and every authenticated LiveView receives a
  `current_scope` assign holding the signed-in `%Alur.Accounts.Account{}` or
  `nil` when nobody is signed in.
  """

  use AlurWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias Alur.Accounts
  alias AlurWeb.Endpoint

  @doc """
  Signs the account in: creates a session token, stores it in the session,
  and redirects to the page the account was heading to, or to the pipeline.
  """
  def log_in_account(conn, account) do
    account_return_to = get_session(conn, :account_return_to)
    token = Accounts.generate_account_session_token(account)

    conn
    |> renew_session()
    |> put_session(:account_token, token)
    |> put_session(:live_socket_id, account_session_topic(token))
    |> delete_session(:account_return_to)
    |> redirect(to: account_return_to || signed_in_path())
  end

  @doc """
  Signs the account out: deletes the session token, renews the session,
  disconnects any live view sockets, and redirects to the sign-in page.
  """
  def log_out_account(conn) do
    account_token = get_session(conn, :account_token)
    account_token && Accounts.delete_account_session_token(account_token)

    if live_socket_id = get_session(conn, :live_socket_id) do
      Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> redirect(to: ~p"/accounts/log-in")
  end

  @doc """
  Assigns `current_scope` on the connection from the session token.

  `current_scope` is the signed-in account or `nil`.
  """
  def fetch_current_scope(conn, _opts) do
    current_scope =
      with token when is_binary(token) <- get_session(conn, :account_token),
           {account, _token} <- Accounts.get_account_by_session_token(token) do
        account
      else
        _ -> nil
      end

    assign(conn, :current_scope, current_scope)
  end

  @doc """
  Redirects accounts that are already signed in away from auth pages.
  """
  def redirect_if_account_is_authenticated(conn, _opts) do
    if conn.assigns.current_scope do
      conn
      |> redirect(to: signed_in_path())
      |> halt()
    else
      conn
    end
  end

  @doc """
  Halts the connection unless an account is signed in, remembering where
  the account wanted to go so it can return there after signing in.
  """
  def require_authenticated_account(conn, _opts) do
    if conn.assigns.current_scope do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> maybe_store_return_to()
      |> redirect(to: ~p"/accounts/log-in")
      |> halt()
    end
  end

  @doc """
  Halts the JSON connection with a `401` unless an account is signed in.

  This is the API counterpart of `require_authenticated_account/2`: JSON
  requests reuse the same browser session cookie (milestone 8 REST), so it
  expects the `:api_authenticated` pipeline to have run `:fetch_session` and
  `:fetch_current_scope` first. Instead of redirecting to the sign-in page it
  answers `401 {"errors":{"detail":...}}` so the Vue app can react.
  """
  def require_api_account(%{assigns: %{current_scope: %Accounts.Account{}}} = conn, _opts) do
    conn
  end

  def require_api_account(conn, _opts) do
    conn
    |> put_status(:unauthorized)
    |> json(%{errors: %{detail: "You must log in to access this resource."}})
    |> halt()
  end

  ## LiveView support

  @doc """
  Handles mounting and authenticating in LiveViews.

  `on_mount` arguments:

    * `:mount_current_scope` - Assigns `current_scope` to the socket based
      on the session token, or `nil` when there is none.

    * `:require_authenticated` - Mounts the current scope, then redirects
      to the sign-in page when no account is signed in.

  Use inside a `live_session` in the router:

      live_session :authenticated,
        on_mount: [{AlurWeb.AccountAuth, :require_authenticated}] do
        live "/", PipelineLive, :index
      end
  """
  def on_mount(:mount_current_scope, _params, session, socket) do
    {:cont, mount_current_scope(socket, session)}
  end

  def on_mount(:require_authenticated, _params, session, socket) do
    socket = mount_current_scope(socket, session)

    if socket.assigns.current_scope do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must log in to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/accounts/log-in")

      {:halt, socket}
    end
  end

  defp mount_current_scope(socket, session) do
    Phoenix.Component.assign_new(socket, :current_scope, fn ->
      with token when is_binary(token) <- session["account_token"],
           {account, _token} <- Accounts.get_account_by_session_token(token) do
        account
      else
        _ -> nil
      end
    end)
  end

  ## Helpers

  defp signed_in_path, do: ~p"/"

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :account_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  defp renew_session(conn) do
    delete_csrf_token()

    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  defp account_session_topic(token), do: "accounts_sessions:#{Base.url_encode64(token)}"
end
