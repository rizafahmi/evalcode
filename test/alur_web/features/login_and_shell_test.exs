defmodule AlurWeb.Features.LoginAndShellTest do
  use AlurWeb.ConnCase

  import Alur.AccountsFixtures

  test "logged-out visitor cannot see the app and is redirected to login", %{conn: conn} do
    conn
    |> visit("/")
    |> assert_path(~p"/users/log-in")
    |> assert_has("[role=alert]", text: "You must log in to access this page.")
    |> refute_has("nav[aria-label='Main Navigation']")
    |> refute_has("a", text: "Log out")

    conn
    |> visit("/contacts")
    |> assert_path(~p"/users/log-in")
    |> refute_has("nav[aria-label='Main Navigation']")

    conn
    |> visit("/todos")
    |> assert_path(~p"/users/log-in")
    |> refute_has("nav[aria-label='Main Navigation']")
  end

  test "user can create an account, see the nav, open the three sections, log out, and log back in",
       %{conn: conn} do
    email = unique_user_email()
    password = valid_user_password()

    # 1. Register
    session =
      conn
      |> visit(~p"/users/register")
      |> fill_in("Email", with: email)
      |> fill_in("Password", with: password)
      |> click_button("Create an account")

    # Lands on home (Pipeline)
    session
    |> assert_path(~p"/")
    |> assert_has("h1", text: "Pipeline")
    |> assert_has("a", text: "Alur")
    |> assert_has("nav[aria-label='Main Navigation']")
    |> assert_has("a", text: "Pipeline")
    |> assert_has("a", text: "Contacts")
    |> assert_has("a", text: "To-dos")
    |> assert_has("a", text: "Log out")
    |> assert_has("span", text: email)

    # 2. Navigate to Contacts
    session =
      session
      |> click_link("Contacts")
      |> assert_path(~p"/contacts")
      |> assert_has("h1", text: "Contacts")

    # 3. Navigate to To-dos
    session =
      session
      |> click_link("To-dos")
      |> assert_path(~p"/todos")
      |> assert_has("h1", text: "To-dos")

    # 4. Navigate back to Pipeline
    session =
      session
      |> click_link("Pipeline")
      |> assert_path(~p"/")
      |> assert_has("h1", text: "Pipeline")

    # 5. Log out
    session =
      session
      |> click_link("Log out")
      |> assert_path(~p"/users/log-in")
      |> refute_has("nav[aria-label='Main Navigation']")
      |> refute_has("a", text: "Log out")

    # 6. Log back in with the created account
    session
    |> fill_in("Email", with: email)
    |> fill_in("Password", with: password)
    |> click_button("Log in")
    |> assert_path(~p"/")
    |> assert_has("h1", text: "Pipeline")
    |> assert_has("span", text: email)
  end
end
