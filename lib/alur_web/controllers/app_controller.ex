defmodule AlurWeb.AppController do
  use AlurWeb, :controller

  def index(conn, _params) do
    render(conn, :index)
  end
end
