defmodule AlurWeb.AccountRegistrationController do
  use AlurWeb, :controller

  alias Alur.Accounts
  alias Alur.Accounts.Account

  def new(conn, _params) do
    changeset = Accounts.change_account_registration(%Account{})
    render(conn, :new, changeset: changeset, page_title: "Register")
  end

  def create(conn, %{"account" => account_params}) do
    case Accounts.register_account(account_params) do
      {:ok, account} ->
        conn
        |> put_flash(:info, "Welcome to Alur! Your account is ready.")
        |> AlurWeb.AccountAuth.log_in_account(account)

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset, page_title: "Register")
    end
  end
end
