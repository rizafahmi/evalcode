defmodule AlurWeb.Features.ContactsTest do
  use AlurWeb.ConnCase

  alias Alur.Accounts.Scope
  alias Alur.AccountsFixtures
  alias Alur.ContactsFixtures

  test "logged-in user can manage contacts: create, search, view, edit, and delete", %{
    conn: conn
  } do
    user = AccountsFixtures.user_fixture()

    session =
      conn
      |> log_in_user(user)
      |> visit(~p"/contacts")
      |> assert_path(~p"/contacts")
      |> assert_has("h1", text: "Contacts")
      |> assert_has("h3", text: "No contacts yet")

    # 1. Add a contact
    session =
      session
      |> click_link("New contact")
      |> assert_path(~p"/contacts/new")
      |> assert_has("h1", text: "New contact")
      |> fill_in("Name", with: "Budi Setiawan")
      |> fill_in("Company", with: "PT Digital Nusantara")
      |> fill_in("Email", with: "budi@nusantara.id")
      |> fill_in("Phone", with: "+628123456789")
      |> fill_in("Notes", with: "Met at Jakarta Tech Expo 2026")
      |> click_button("Save contact")
      |> assert_path(~p"/contacts")
      |> assert_has("[role=alert]", text: "Contact created successfully.")
      |> assert_has("td", text: "Budi Setiawan")
      |> assert_has("td", text: "PT Digital Nusantara")
      |> assert_has("td", text: "budi@nusantara.id")

    # Add a second contact to test searching
    session =
      session
      |> click_link("New contact")
      |> fill_in("Name", with: "Siti Rahmawati")
      |> fill_in("Company", with: "Siti Studio")
      |> fill_in("Email", with: "siti@studio.id")
      |> click_button("Save contact")
      |> assert_has("td", text: "Budi Setiawan")
      |> assert_has("td", text: "Siti Rahmawati")

    # 2. Find by name
    session =
      session
      |> fill_in("Search contacts", with: "Rahma")
      |> assert_has("td", text: "Siti Rahmawati")
      |> refute_has("td", text: "Budi Setiawan")

    # Clear search
    session =
      session
      |> click_button("Clear search")
      |> assert_has("td", text: "Budi Setiawan")
      |> assert_has("td", text: "Siti Rahmawati")

    # 3. Open contact detail page
    session =
      session
      |> click_link("Budi Setiawan")
      |> assert_has("h1", text: "Budi Setiawan")
      |> assert_has("dd", text: "Budi Setiawan")
      |> assert_has("dd", text: "PT Digital Nusantara")
      |> assert_has("dd", text: "budi@nusantara.id")
      |> assert_has("dd", text: "+628123456789")
      |> assert_has("dd", text: "Met at Jakarta Tech Expo 2026")

    # 4. Edit contact from detail page
    session =
      session
      |> click_link("Edit")
      |> assert_has("h1", text: "Edit contact")
      |> fill_in("Name", with: "Budi Setiawan, M.Kom")
      |> fill_in("Company", with: "PT Nusantara Digital Utama")
      |> click_button("Save contact")
      |> assert_has("[role=alert]", text: "Contact updated successfully.")
      |> assert_has("h1", text: "Budi Setiawan, M.Kom")
      |> assert_has("dd", text: "PT Nusantara Digital Utama")

    # 5. Delete contact from detail page
    session =
      session
      |> click_button("Delete")
      |> assert_path(~p"/contacts")
      |> assert_has("[role=alert]", text: "Contact deleted successfully.")
      |> refute_has("td", text: "Budi Setiawan")
      |> assert_has("td", text: "Siti Rahmawati")

    # 6. Delete remaining contact from list
    session
    |> click_button("Delete")
    |> assert_has("[role=alert]", text: "Contact deleted successfully.")
    |> refute_has("td", text: "Siti Rahmawati")
    |> assert_has("h3", text: "No contacts yet")
  end

  test "contact creation validates required fields", %{conn: conn} do
    user = AccountsFixtures.user_fixture()

    conn
    |> log_in_user(user)
    |> visit(~p"/contacts/new")
    |> fill_in("Name", with: "")
    |> click_button("Save contact")
    |> assert_has("p", text: "can't be blank")
  end

  test "another account does not see or access that contact", %{conn: conn} do
    user_a = AccountsFixtures.user_fixture()
    user_b = AccountsFixtures.user_fixture()

    scope_a = Scope.for_user(user_a)

    contact_a =
      ContactsFixtures.contact_fixture(scope_a, %{
        name: "Private Contact of User A",
        email: "private_a@example.com",
        company: "Secret Holdings"
      })

    # User B logs in and visits contacts list
    session_b =
      conn
      |> log_in_user(user_b)
      |> visit(~p"/contacts")
      |> refute_has("td", text: "Private Contact of User A")
      |> refute_has("td", text: "private_a@example.com")
      |> refute_has("td", text: "Secret Holdings")

    # User B searches for User A's contact name
    session_b
    |> fill_in("Search contacts", with: "Private Contact")
    |> assert_has("h3", text: "No contacts found")
    |> refute_has("td", text: "Private Contact of User A")

    # User B attempts to access User A's contact detail page directly
    assert_raise Ecto.NoResultsError, fn ->
      conn
      |> log_in_user(user_b)
      |> visit(~p"/contacts/#{contact_a.id}")
    end

    # User B attempts to access User A's contact edit page directly
    assert_raise Ecto.NoResultsError, fn ->
      conn
      |> log_in_user(user_b)
      |> visit(~p"/contacts/#{contact_a.id}/edit")
    end
  end
end
