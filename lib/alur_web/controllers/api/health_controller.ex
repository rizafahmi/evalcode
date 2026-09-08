defmodule AlurWeb.Api.HealthController do
  use AlurWeb, :controller

  def show(conn, _params) do
    json(conn, %{status: "ok"})
  end
end
