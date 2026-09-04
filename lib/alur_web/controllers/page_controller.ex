defmodule AlurWeb.PageController do
  use AlurWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
