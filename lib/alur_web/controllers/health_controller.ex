defmodule AlurWeb.HealthController do
  use AlurWeb, :controller

  def index(conn, _params) do
    json(conn, %{status: "ok"})
  end
end
