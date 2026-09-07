defmodule AlurWeb.HealthController do
  @moduledoc """
  Serves the unauthenticated JSON health check for the `/api` surface.

  The body is intentionally the single exact object the PRD locks in:
  `{"status":"ok"}` — no extra fields, no version, no uptime.
  """

  use AlurWeb, :controller

  def index(conn, _params) do
    json(conn, %{status: "ok"})
  end
end
