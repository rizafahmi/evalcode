defmodule AlurWeb.AccountSessionController do
  use AlurWeb, :controller

  alias Alur.Accounts

  def new(conn, _params) do
    email = conn.assigns.current_scope && conn.assigns.current_scope.email
    form = Phoenix.Component.to_form(%{"email" => email}, as: "account")
    render(conn, :new, form: form, page_title: "Log in")
  end

  def create(conn, %{"account" => %{"email" => email, "password" => password}} = _params) do
    if account = Accounts.get_account_by_email_and_password(email, password) do
      conn
      |> put_flash(:info, "Welcome back!")
      |> AlurWeb.AccountAuth.log_in_account(account)
    else
      form = Phoenix.Component.to_form(%{"email" => email}, as: "account")

      conn
      |> put_flash(:error, "Invalid email or password")
      |> render(:new, form: form)
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> AlurWeb.AccountAuth.log_out_account()
  end
end
