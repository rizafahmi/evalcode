defmodule AlurWeb.ContactLive.FormTest do
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

  describe "new contact" do
    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/contacts/new")
    end

    test "validates required name field", %{conn: conn, user: user} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/contacts/new")

      html =
        lv
        |> form("#contact-form", contact: %{name: ""})
        |> render_change()

      assert html =~ "can&#39;t be blank"
    end

    test "creates contact and redirects to contacts list", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/contacts/new")

      {:ok, _index_lv, html} =
        lv
        |> form("#contact-form",
          contact: %{
            name: "Raden Saleh",
            company: "Indonesian Art Studio",
            email: "raden.saleh@art.id",
            phone: "+62819876543",
            notes: "Renowned painter"
          }
        )
        |> render_submit()
        |> follow_redirect(conn, ~p"/contacts")

      assert html =~ "Contact created successfully."
      assert html =~ "Raden Saleh"
    end
  end

  describe "edit contact" do
    test "redirects if user is not logged in", %{conn: conn, scope: scope} do
      contact = ContactsFixtures.contact_fixture(scope)

      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/contacts/#{contact}/edit")
    end

    test "cannot edit another user's contact", %{conn: conn, user: user} do
      other_user = AccountsFixtures.user_fixture()
      other_scope = Scope.for_user(other_user)
      other_contact = ContactsFixtures.contact_fixture(other_scope)

      assert_raise Ecto.NoResultsError, fn ->
        conn
        |> log_in_user(user)
        |> live(~p"/contacts/#{other_contact}/edit")
      end
    end

    test "updates contact and redirects to contact detail page", %{
      conn: conn,
      user: user,
      scope: scope
    } do
      contact = ContactsFixtures.contact_fixture(scope, %{name: "Original Name"})

      conn = log_in_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/contacts/#{contact}/edit")

      {:ok, _show_lv, html} =
        lv
        |> form("#contact-form", contact: %{name: "Updated Name", company: "New Enterprise"})
        |> render_submit()
        |> follow_redirect(conn, ~p"/contacts/#{contact}")

      assert html =~ "Contact updated successfully."
      assert html =~ "Updated Name"
      assert html =~ "New Enterprise"
    end
  end
end
