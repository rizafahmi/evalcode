defmodule AlurWeb.LogInTest do
  use AlurWeb.ConnCase, async: false

  alias Alur.Accounts

  @email "sari@example.com"
  @password "super secret 1234"

  setup do
    {:ok, account} =
      Accounts.register_account(%{
        email: @email,
        password: @password,
        password_confirmation: @password
      })

    %{account: account}
  end

  test "account can log in with email and password", %{conn: conn} do
    conn
    |> visit("/accounts/log-in")
    |> fill_in("Email", with: @email)
    |> fill_in("Password", with: @password)
    |> click_button("Log in")
    |> assert_has("h1", text: "Deal pipeline")
    |> assert_has("#flash-info", text: "Welcome back!")
  end

  test "log in page links to registration", %{conn: conn} do
    conn
    |> visit("/accounts/log-in")
    |> click_link("Create an account")
    |> assert_has("h1", text: "Create your account")
  end

  test "wrong password shows an error and stays on log in", %{conn: conn} do
    conn
    |> visit("/accounts/log-in")
    |> fill_in("Email", with: @email)
    |> fill_in("Password", with: "definitely not right")
    |> click_button("Log in")
    |> assert_has("h1", text: "Log in to Alur")
    |> assert_has("#flash-error", text: "Invalid email or password")
    |> refute_has("h1", text: "Deal pipeline")
  end

  test "registration page links to log in", %{conn: conn} do
    conn
    |> visit("/accounts/register")
    |> click_link("Log in")
    |> assert_has("h1", text: "Log in to Alur")
  end
end
