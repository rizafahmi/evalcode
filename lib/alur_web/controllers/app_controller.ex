defmodule AlurWeb.AppController do
  @moduledoc """
  Serves the authenticated `/app` page where the Vue application mounts.

  This is a plain controller page — deliberately *not* a LiveView and not
  inside the `:authenticated` live_session. The server renders an empty
  mount node (`<div id="app">`) plus the Vite-built Vue entry script; Vue
  takes over from there. `/app` is where milestone 8 grows the Vue Kanban.
  """

  use AlurWeb, :controller

  def index(conn, _params) do
    render(conn, :index, page_title: "Deal board")
  end
end
