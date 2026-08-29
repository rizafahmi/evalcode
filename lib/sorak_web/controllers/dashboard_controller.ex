defmodule SorakWeb.DashboardController do
  use SorakWeb, :controller

  def index(conn, _params) do
    render(conn, :index)
  end
end
