defmodule AlurWeb.DealsFeatureTest do
  use AlurWeb.ConnCase, async: false

  alias Alur.Accounts
  alias Alur.Contacts
  alias Alur.Deals

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

  defp add_sari(conn) do
    conn
    |> click_link("New contact")
    |> fill_in("Name", with: "Sari Wijaya")
    |> fill_in("Company", with: "Acme")
    |> click_button("Save contact")
  end

  defp column_id(name) do
    Enum.find(Deals.list_pipeline_columns(), &(&1.name == name)).id
  end

  test "a deal's full lifecycle: create from a contact, rupiah everywhere, edit, delete", %{
    conn: conn
  } do
    conn
    |> register_and_visit_contacts()
    |> add_sari()
    # The contact page shows an empty deals panel with a New deal entry point
    |> refute_has("#contact-deals")
    |> assert_has("main", text: "No deals for this contact yet.")
    |> click_link("New deal")
    |> assert_has("h1", text: "New deal")
    |> assert_has("main", text: "Deal for")
    |> assert_has("select", selected: "Lead", label: "Pipeline column")
    |> fill_in("Title", with: "Website redesign")
    |> fill_in("Value (IDR)", with: "15000000")
    |> fill_in("Notes", with: "Quoted for the full relaunch.")
    |> click_button("Save deal")
    |> assert_has("#flash-info", text: "Deal created successfully.")
    |> assert_has("h1", text: "Website redesign")
    |> assert_has("main", text: "Rp 15.000.000")
    |> assert_has("main", text: "Lead")
    |> assert_has("main", text: "Quoted for the full relaunch.")
    # Back on the contact, the deal shows in the contact's list with its rupiah value
    |> click_link("Back to Sari Wijaya")
    |> assert_has("#contact-deals", text: "Website redesign")
    |> assert_has("#contact-deals", text: "Rp 15.000.000")
    |> assert_has("#contact-deals", text: "Lead")
    # Open the deal from the contact, then edit value and column on the deal page
    |> click_link("Website redesign")
    |> assert_has("h1", text: "Website redesign")
    |> click_link("Edit deal")
    |> assert_has("h1", text: "Edit deal")
    |> assert_has("input", value: "Website redesign", label: "Title")
    |> assert_has("input", value: "15000000", label: "Value (IDR)")
    |> fill_in("Value (IDR)", with: "20000000")
    |> select("Pipeline column", option: "Meeting")
    |> click_button("Save deal")
    |> assert_has("#flash-info", text: "Deal updated successfully.")
    |> assert_has("h1", text: "Website redesign")
    |> assert_has("main", text: "Rp 20.000.000")
    |> assert_has("main", text: "Meeting")
    # Delete it from its page; the contact's list is empty again
    |> click_button("Delete")
    |> assert_has("#flash-info", text: "Deal deleted successfully.")
    |> assert_has("main", text: "No deals for this contact yet.")
  end

  test "an account never sees another account's deals", %{conn: conn} do
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

    {:ok, deal_a} =
      Deals.create_deal(account_a, contact_a, %{
        title: "Secret opportunity",
        amount: 50_000_000,
        pipeline_column_id: column_id("Lead")
      })

    conn
    |> log_in_as("budi@example.com")
    # Budi's own contact never lists Sari's deal
    |> click_link("Contacts")
    |> click_link("Budi Santoso")
    |> assert_has("main", text: "No deals for this contact yet.")
    # Directly opening Sari's deal or her new-deal form bounces to Budi's list
    |> visit("/deals/#{deal_a.id}")
    |> assert_has("#flash-error", text: "Deal not found.")
    |> assert_path("/contacts")
    |> visit("/contacts/#{contact_a.id}/deals/new")
    |> assert_has("#flash-error", text: "Contact not found.")
    |> assert_path("/contacts")
  end

  test "the new-deal form reports missing titles, values, and negative amounts", %{conn: conn} do
    conn
    |> register_and_visit_contacts()
    |> add_sari()
    |> click_link("New deal")
    |> click_button("Save deal")
    |> assert_has("h1", text: "New deal")
    |> assert_has("main", text: "can't be blank")
    |> fill_in("Title", with: "Too cheap")
    |> fill_in("Value (IDR)", with: "-50000")
    |> click_button("Save deal")
    |> assert_has("h1", text: "New deal")
    |> assert_has("main", text: "must be 0 or a positive whole number of rupiah")
  end
end
