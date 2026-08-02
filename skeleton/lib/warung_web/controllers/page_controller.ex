defmodule WarungWeb.PageController do
  use WarungWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
