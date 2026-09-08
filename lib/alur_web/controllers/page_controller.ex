defmodule AlurWeb.PageController do
  use AlurWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  def app(conn, _params) do
    render(conn, :app)
  end
end
