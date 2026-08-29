defmodule SorakWeb.PageController do
  use SorakWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
