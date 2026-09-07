defmodule AlurWeb.ActivityLogFeatureTest do
  use AlurWeb.ConnCase, async: false

  alias Alur.Accounts
  alias Alur.Contacts
  alias Alur.Deals
  alias Phoenix.LiveViewTest

  @password "super secret 1234"

  defp register!(email) do
    {:ok, account} =
      Accounts.register_account(%{
        email: email,
        password: @password,
        password_confirmation: @password
      })

    account
  end

  defp contact!(account, name) do
    {:ok, contact} = Contacts.create_contact(account, %{name: name})
    contact
  end

  defp deal!(account, contact, attrs) do
    {:ok, deal} = Deals.create_deal(account, contact, attrs)
    deal
  end

  defp column(name) do
    Enum.find(Deals.list_pipeline_columns(), &(&1.name == name))
  end

  defp log_in_as(conn, email) do
    conn
    |> visit("/accounts/log-in")
    |> fill_in("Email", with: email)
    |> fill_in("Password", with: @password)
    |> click_button("Log in")
  end

  defp register_and_add_deal(conn) do
    conn
    |> visit("/accounts/register")
    |> fill_in("Email", with: "sari@example.com")
    |> fill_in("Password", with: @password)
    |> fill_in("Confirm password", with: @password)
    |> click_button("Create account")
    |> click_link("Contacts")
    |> click_link("New contact")
    |> fill_in("Name", with: "Sari Wijaya")
    |> click_button("Save contact")
    |> click_link("New deal")
    |> fill_in("Title", with: "Website redesign")
    |> fill_in("Value (IDR)", with: "15000000")
    |> click_button("Save deal")
  end

  test "a deal opens with a created line, notes join it newest-first, and moves from the edit page are logged",
       %{conn: conn} do
    conn
    |> register_and_add_deal()
    # The deal page shows the activity log with its opening created line, timestamped.
    |> assert_has("#deal-activity-log", text: "Activity log")
    |> assert_has(".activity-row", count: 1)
    |> assert_has(".activity-row", text: "Deal created")
    |> assert_has("#deal-activity-log time", count: 1)
    |> assert_has("#deal-activity-log time", text: "WIB")
    # Log lines themselves carry no edit or delete affordances.
    |> refute_has(".activity-row a")
    |> refute_has(".activity-row button")
    # A free-text note joins the log above the created line.
    |> fill_in("Add a note", with: "Called Sari about the proposal.")
    |> click_button("Add note")
    |> assert_has("#flash-info", text: "Note added to the activity log.")
    |> assert_has(".activity-row", count: 2)
    |> assert_has(".activity-row", at: 1, text: "Note: Called Sari about the proposal.")
    |> assert_has(".activity-row", at: 2, text: "Deal created")
    # Changing the column on the edit page writes a timestamped move line.
    |> click_link("Edit deal")
    |> select("Pipeline column", option: "Meeting")
    |> click_button("Save deal")
    |> assert_has("#flash-info", text: "Deal updated successfully.")
    |> assert_has("#deal-activity-log time", count: 3)
    |> assert_has(".activity-row", count: 3)
    |> assert_has(".activity-row", at: 1, text: "Moved from Lead to Meeting")
    |> assert_has(".activity-row", at: 2, text: "Note: Called Sari about the proposal.")
    |> assert_has(".activity-row", at: 3, text: "Deal created")
  end

  test "dragging a card on the board writes a move line visible on the deal's log", %{conn: conn} do
    account = register!("puri@example.com")
    contact = contact!(account, "Sari Wijaya")

    lead_deal =
      deal!(account, contact, %{
        title: "Website redesign",
        amount: 15_000_000,
        pipeline_column_id: column("Lead").id
      })

    conn
    |> log_in_as("puri@example.com")
    |> unwrap(fn view ->
      # "Dropping" the card on Meeting is the server event the drag hook sends.
      LiveViewTest.render_hook(view, "move_deal", %{
        "deal_id" => lead_deal.id,
        "column_id" => column("Meeting").id
      })
    end)
    |> click_link("Website redesign")
    |> assert_has("h1", text: "Website redesign")
    |> assert_has(".activity-row", count: 2)
    |> assert_has(".activity-row", at: 1, text: "Moved from Lead to Meeting")
    |> assert_has(".activity-row", at: 2, text: "Deal created")
    |> assert_has("#deal-activity-log time", count: 2)
  end

  test "an account never sees another account's deal log", %{conn: conn} do
    sari = register!("sari@example.com")
    budi = register!("budi@example.com")
    sari_contact = contact!(sari, "Sari Raharjo")
    budi_contact = contact!(budi, "Budi Santoso")

    sari_deal =
      deal!(sari, sari_contact, %{
        title: "Secret opportunity",
        amount: 50_000_000,
        pipeline_column_id: column("Lead").id
      })

    {:ok, _line} =
      Alur.Activities.log(sari_deal, "Note: private details only Sari should see")

    budi_deal =
      deal!(budi, budi_contact, %{
        title: "Budi's proposal",
        amount: 25_000_000,
        pipeline_column_id: column("Lead").id
      })

    conn
    |> log_in_as("budi@example.com")
    # Directly opening Sari's deal (and so its log) bounces to Budi's contacts.
    |> visit("/deals/#{sari_deal.id}")
    |> assert_has("#flash-error", text: "Deal not found.")
    |> assert_path("/contacts")
    # Budi's own deal page shows only Budi's own created line.
    |> visit("/deals/#{budi_deal.id}")
    |> assert_has("h1", text: "Budi's proposal")
    |> assert_has(".activity-row", count: 1)
    |> assert_has(".activity-row", text: "Deal created")
    |> refute_has("main", text: "private details only Sari should see")
  end
end
