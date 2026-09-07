defmodule AlurWeb.RegisterAndShellTest do
  use AlurWeb.ConnCase, async: false

  @email "ari@example.com"
  @password "super secret 1234"

  describe "registering" do
    test "a logged-out visitor is redirected away from the app pages", %{conn: conn} do
      for path <- ["/", "/contacts", "/todos"] do
        redirected = get(conn, path)

        assert redirected.status == 302
        assert Phoenix.ConnTest.redirected_to(redirected) == "/accounts/log-in"
      end
    end

    test "visitor creates an account and reaches the signed-in shell", %{conn: conn} do
      conn
      |> visit("/accounts/register")
      |> assert_has("h1", text: "Create your account")
      |> fill_in("Email", with: @email)
      |> fill_in("Password", with: @password)
      |> fill_in("Confirm password", with: @password)
      |> click_button("Create account")
      |> assert_has("h1", text: "Deal pipeline")
      |> assert_has("#flash-info", text: "Welcome to Alur!")
      |> assert_has("header", text: "Pipeline")
      |> assert_has("header", text: "Contacts")
      |> assert_has("header", text: "To-dos")
      |> assert_has("header", text: "Log out")
    end

    test "visitor can open every section from the nav", %{conn: conn} do
      conn
      |> visit("/accounts/register")
      |> fill_in("Email", with: @email)
      |> fill_in("Password", with: @password)
      |> fill_in("Confirm password", with: @password)
      |> click_button("Create account")
      |> assert_path("/")
      |> click_link("Contacts")
      |> assert_has("h1", text: "Contacts")
      |> assert_has("h2", text: "No contacts yet")
      |> click_link("To-dos")
      |> assert_has("h1", text: "To-dos")
      |> assert_has("h2", text: "Nothing due")
      |> click_link("Pipeline")
      |> assert_has("h1", text: "Deal pipeline")
    end

    test "visitor can log out, after which the app is out of reach", %{conn: conn} do
      conn
      |> visit("/accounts/register")
      |> fill_in("Email", with: @email)
      |> fill_in("Password", with: @password)
      |> fill_in("Confirm password", with: @password)
      |> click_button("Create account")
      |> click_link("Log out")
      |> assert_has("h1", text: "Log in to Alur")
      |> assert_has("#flash-info", text: "Logged out successfully.")
      |> refute_has("nav", text: "Log out")
      |> visit("/")
      |> assert_has("h1", text: "Log in to Alur")
      |> refute_has("h1", text: "Deal pipeline")
    end
  end
end
