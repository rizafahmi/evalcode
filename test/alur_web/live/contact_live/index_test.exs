defmodule AlurWeb.ContactLive.IndexTest do
  use AlurWeb.ConnCase

  import Phoenix.LiveViewTest
  alias Alur.Accounts.Scope
  alias Alur.AccountsFixtures
  alias Alur.ContactsFixtures

  setup do
    user = AccountsFixtures.user_fixture()
    scope = Scope.for_user(user)
    %{user: user, scope: scope}
  end

  test "redirects if user is not logged in", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/contacts")
  end

  test "lists contacts belonging to user", %{conn: conn, user: user, scope: scope} do
    _contact =
      ContactsFixtures.contact_fixture(scope, %{name: "Ahmad Dahlan", company: "Muhammadiyah"})

    other_user = AccountsFixtures.user_fixture()
    other_scope = Scope.for_user(other_user)
    _other_contact = ContactsFixtures.contact_fixture(other_scope, %{name: "Other Person"})

    {:ok, _lv, html} =
      conn
      |> log_in_user(user)
      |> live(~p"/contacts")

    assert html =~ "Ahmad Dahlan"
    assert html =~ "Muhammadiyah"
    refute html =~ "Other Person"
  end

  test "searches contacts by name", %{conn: conn, user: user, scope: scope} do
    ContactsFixtures.contact_fixture(scope, %{name: "Dewi Sartika"})
    ContactsFixtures.contact_fixture(scope, %{name: "Cut Nyak Dien"})

    {:ok, lv, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/contacts")

    html =
      lv
      |> form("form[phx-change=search]", %{"search" => "Sartika"})
      |> render_change()

    assert html =~ "Dewi Sartika"
    refute html =~ "Cut Nyak Dien"

    # Clear search
    html = lv |> element("button[aria-label='Clear search']") |> render_click()
    assert html =~ "Dewi Sartika"
    assert html =~ "Cut Nyak Dien"
  end

  test "deletes a contact from list", %{conn: conn, user: user, scope: scope} do
    contact = ContactsFixtures.contact_fixture(scope, %{name: "To Delete"})

    {:ok, lv, html} =
      conn
      |> log_in_user(user)
      |> live(~p"/contacts")

    assert html =~ "To Delete"

    html =
      lv
      |> element("#contact-#{contact.id} button", "Delete")
      |> render_click()

    assert html =~ "Contact deleted successfully."
    refute html =~ "To Delete"
  end
end
