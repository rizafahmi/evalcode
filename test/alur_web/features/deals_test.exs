defmodule AlurWeb.Features.DealsTest do
  use AlurWeb.ConnCase

  alias Alur.Accounts.Scope
  alias Alur.AccountsFixtures
  alias Alur.DealsFixtures

  test "complete deal lifecycle from contact: create, view with IDR format, change column, list, and delete",
       %{conn: conn} do
    user = AccountsFixtures.user_fixture()

    session =
      conn
      |> log_in_user(user)
      |> visit(~p"/contacts/new")
      |> fill_in("Name", with: "Dewi Lestari")
      |> fill_in("Company", with: "Aroma Nusantara")
      |> fill_in("Email", with: "dewi@aroma.id")
      |> click_button("Save contact")
      |> assert_path(~p"/contacts")
      |> click_link("Dewi Lestari")
      |> assert_has("h1", text: "Dewi Lestari")
      |> assert_has("h3", text: "No deals yet")

    # 1. Create a deal from the contact
    session =
      session
      |> click_link("New deal")
      |> assert_has("h1", text: "New deal")
      |> fill_in("Title", with: "Consulting Retainer 2026")
      |> fill_in("Amount (IDR)", with: "15000000")
      |> fill_in("Notes", with: "Scope defined over email")
      |> click_button("Save deal")

    # 2. Open it and see rupiah formatting
    session =
      session
      |> assert_has("[role=alert]", text: "Deal created successfully.")
      |> assert_has("h1", text: "Consulting Retainer 2026")
      |> assert_has("dd", text: "Rp 15.000.000")
      |> assert_has("a", text: "Dewi Lestari")
      |> assert_has("span", text: "Lead")
      |> assert_has("dd", text: "Scope defined over email")

    # 3. Change the column on the deal page
    session =
      session
      |> click_button("Proposal")
      |> assert_has("[role=alert]", text: "Deal stage updated to Proposal.")
      |> assert_has("span", text: "Proposal")

    # 4. Contact detail lists that contact's deal
    session =
      session
      |> click_link("Back to Dewi Lestari")
      |> assert_has("h1", text: "Dewi Lestari")
      |> assert_has("td", text: "Consulting Retainer 2026")
      |> assert_has("td", text: "Rp 15.000.000")
      |> assert_has("td", text: "Proposal")

    # 5. Open the deal from contact list and delete it
    session
    |> click_link("Consulting Retainer 2026")
    |> assert_has("h1", text: "Consulting Retainer 2026")
    |> click_button("Delete")
    |> assert_has("[role=alert]", text: "Deal deleted successfully.")
    |> assert_has("h1", text: "Dewi Lestari")
    |> assert_has("h3", text: "No deals yet")
    |> refute_has("td", text: "Consulting Retainer 2026")
  end

  test "another account cannot see or access deals created by a different account", %{conn: conn} do
    user_a = AccountsFixtures.user_fixture()
    user_b = AccountsFixtures.user_fixture()

    scope_a = Scope.for_user(user_a)

    deal_a =
      DealsFixtures.deal_fixture(scope_a, %{
        title: "Confidential Enterprise Deal",
        amount: 80_000_000
      })

    # User B logs in and attempts to access User A's deal
    assert_raise Ecto.NoResultsError, fn ->
      conn
      |> log_in_user(user_b)
      |> visit(~p"/deals/#{deal_a.id}")
    end

    # User B attempts to access edit form of User A's deal
    assert_raise Ecto.NoResultsError, fn ->
      conn
      |> log_in_user(user_b)
      |> visit(~p"/deals/#{deal_a.id}/edit")
    end
  end
end
