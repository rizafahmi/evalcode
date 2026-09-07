defmodule AlurWeb.ContactsFeatureTest do
  use AlurWeb.ConnCase, async: false

  alias Alur.Accounts
  alias Alur.Contacts

  @email "sari@example.com"
  @password "super secret 1234"

  defp register_and_visit_contacts(conn) do
    conn
    |> visit("/accounts/register")
    |> fill_in("Email", with: @email)
    |> fill_in("Password", with: @password)
    |> fill_in("Confirm password", with: @password)
    |> click_button("Create account")
    |> click_link("Contacts")
  end

  defp log_in_as(conn, email) do
    conn
    |> visit("/accounts/log-in")
    |> fill_in("Email", with: email)
    |> fill_in("Password", with: @password)
    |> click_button("Log in")
  end

  test "a contact's full lifecycle: add, find by name, open, edit, delete", %{conn: conn} do
    conn
    |> register_and_visit_contacts()
    |> assert_has("h2", text: "No contacts yet")
    |> click_link("New contact")
    |> assert_has("h1", text: "New contact")
    |> fill_in("Name", with: "Sari Wijaya")
    |> fill_in("Email", with: "sari@acme.example")
    |> fill_in("Phone", with: "+62 812 3456 7890")
    |> fill_in("Company", with: "Acme")
    |> fill_in("Notes", with: "Met at the Jakarta meetup.")
    |> click_button("Save contact")
    |> assert_has("#flash-info", text: "Contact created successfully.")
    |> assert_has("h1", text: "Sari Wijaya")
    |> assert_has("main", text: "sari@acme.example")
    |> assert_has("main", text: "+62 812 3456 7890")
    |> assert_has("main", text: "Met at the Jakarta meetup.")
    |> click_link("All contacts")
    |> assert_has("#contacts", text: "Sari Wijaya")
    |> assert_has("#contacts", text: "Acme")
    |> click_link("New contact")
    |> fill_in("Name", with: "Bambang Nugroho")
    |> fill_in("Company", with: "Nusantara")
    |> click_button("Save contact")
    |> click_link("All contacts")
    |> assert_has("#contacts", text: "Sari Wijaya")
    |> assert_has("#contacts", text: "Bambang Nugroho")
    # Search filters by name as you type
    |> fill_in("Search contacts by name", with: "Bambang")
    |> assert_has("#contacts", text: "Bambang Nugroho")
    |> refute_has("#contacts", "Sari Wijaya")
    |> fill_in("Search contacts by name", with: "")
    |> assert_has("#contacts", text: "Sari Wijaya")
    |> assert_has("#contacts", text: "Bambang Nugroho")
    # A search that matches nobody shows its own empty state and can be cleared
    |> fill_in("Search contacts by name", with: "zzz")
    |> assert_has("h2", text: "No contacts found")
    |> click_button("Clear search")
    |> assert_has("#contacts", text: "Sari Wijaya")
    # Open the contact from the list, then edit it
    |> click_link("Sari Wijaya")
    |> assert_has("h1", text: "Sari Wijaya")
    |> click_link("Edit contact")
    |> assert_has("h1", text: "Edit contact")
    |> assert_has("input", value: "Sari Wijaya", label: "Name")
    |> assert_has("input", value: "sari@acme.example", label: "Email")
    |> fill_in("Company", with: "PT Acme")
    |> click_button("Save contact")
    |> assert_has("#flash-info", text: "Contact updated successfully.")
    |> assert_has("h1", text: "Sari Wijaya")
    |> assert_has("main", text: "PT Acme")
    # Delete it from its page; it disappears from the list
    |> click_button("Delete")
    |> assert_has("#flash-info", text: "Contact deleted successfully.")
    |> assert_path("/contacts")
    |> assert_has("#contacts", text: "Bambang Nugroho")
    |> refute_has("#contacts", "Sari Wijaya")
  end

  test "an account never sees another account's contacts", %{conn: conn} do
    {:ok, account_a} =
      Accounts.register_account(%{
        email: "ani@example.com",
        password: @password,
        password_confirmation: @password
      })

    {:ok, account_b} =
      Accounts.register_account(%{
        email: "budi@example.com",
        password: @password,
        password_confirmation: @password
      })

    {:ok, contact_a} = Contacts.create_contact(account_a, %{name: "Sari Raharjo"})
    {:ok, _contact_b} = Contacts.create_contact(account_b, %{name: "Budi Santoso"})

    conn
    |> log_in_as("budi@example.com")
    |> click_link("Contacts")
    |> assert_has("#contacts", text: "Budi Santoso")
    |> refute_has("#contacts", "Sari Raharjo")
    # Directly opening the other account's contact redirects to the own list
    |> visit("/contacts/#{contact_a.id}")
    |> assert_has("#flash-error", text: "Contact not found.")
    |> assert_path("/contacts")
    |> assert_has("#contacts", text: "Budi Santoso")
    |> refute_has("#contacts", "Sari Raharjo")
  end

  test "the new-contact form reports missing names and malformed emails", %{conn: conn} do
    conn
    |> register_and_visit_contacts()
    |> click_link("New contact")
    |> fill_in("Email", with: "not-an-email")
    |> click_button("Save contact")
    |> assert_has("h1", text: "New contact")
    |> assert_has("main", text: "can't be blank")
    |> assert_has("main", text: "must have the @ sign and no spaces")
  end
end
