defmodule AlurWeb.ContactLive.ShowTest do
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

  test "redirects if user is not logged in", %{conn: conn, scope: scope} do
    contact = ContactsFixtures.contact_fixture(scope)
    assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/contacts/#{contact}")
  end

  test "displays contact details", %{conn: conn, user: user, scope: scope} do
    contact =
      ContactsFixtures.contact_fixture(scope, %{
        name: "Ki Hajar Dewantara",
        company: "Taman Siswa",
        email: "kihajar@tamansiswa.id",
        phone: "+62812345678",
        notes: "Founder of national education"
      })

    {:ok, _lv, html} =
      conn
      |> log_in_user(user)
      |> live(~p"/contacts/#{contact}")

    assert html =~ "Ki Hajar Dewantara"
    assert html =~ "Taman Siswa"
    assert html =~ "kihajar@tamansiswa.id"
    assert html =~ "+62812345678"
    assert html =~ "Founder of national education"
  end

  test "cannot access another user's contact", %{conn: conn, user: user} do
    other_user = AccountsFixtures.user_fixture()
    other_scope = Scope.for_user(other_user)
    other_contact = ContactsFixtures.contact_fixture(other_scope, %{name: "Private Contact"})

    assert_raise Ecto.NoResultsError, fn ->
      conn
      |> log_in_user(user)
      |> live(~p"/contacts/#{other_contact}")
    end
  end

  test "deletes contact from show page", %{conn: conn, user: user, scope: scope} do
    contact = ContactsFixtures.contact_fixture(scope, %{name: "Contact To Remove"})

    conn = log_in_user(conn, user)
    {:ok, lv, _html} = live(conn, ~p"/contacts/#{contact}")

    {:ok, _index_lv, html} =
      lv
      |> element("button", "Delete")
      |> render_click()
      |> follow_redirect(conn, ~p"/contacts")

    assert html =~ "Contact deleted successfully."
    refute html =~ "Contact To Remove"
  end
end
