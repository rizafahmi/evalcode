defmodule AlurWeb.NextActionsFeatureTest do
  use AlurWeb.ConnCase, async: false

  alias Alur.Accounts
  alias Alur.Contacts
  alias Alur.Deals
  alias Alur.NextActions
  alias Alur.NextActions.NextAction

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

  test "add a follow-up on a deal, complete it from the to-dos page, and see both logged",
       %{conn: conn} do
    account = register!("sari@example.com")
    contact = contact!(account, "Sari Wijaya")

    deal =
      deal!(account, contact, %{
        title: "Website redesign",
        amount: 15_000_000,
        pipeline_column_id: column("Lead").id
      })

    due = Date.add(Date.utc_today(), 10)
    due_display = NextActions.format_due(%NextAction{due_date: due, due_time: ~T[14:00:00]})

    conn
    |> log_in_as("sari@example.com")
    |> visit("/deals/#{deal.id}")
    |> assert_has("h1", text: "Website redesign")
    # The deal starts with an empty Next actions panel…
    |> assert_has("#deal-next-actions", text: "Next actions")
    |> assert_has("#deal-next-actions", text: "0 open")
    |> assert_has("#deal-next-actions", text: "No follow-ups scheduled yet.")
    # …then a follow-up with a due date and optional time is added there.
    |> fill_in("What to do", with: "Call Sari about the proposal")
    |> fill_in("Due date", with: Date.to_iso8601(due))
    |> fill_in("Due time (optional)", with: "14:00")
    |> click_button("Add follow-up")
    |> assert_has("#flash-info", text: "Follow-up added.")
    |> assert_has("#deal-next-actions", text: "1 open")
    |> assert_has(".next-action-row", count: 1)
    |> assert_has(".next-action-row", text: "Call Sari about the proposal")
    # Adding it wrote a matching activity-log line above the created line.
    |> assert_has(".activity-row", count: 2)
    |> assert_has(".activity-row", at: 1, text: "Follow-up added: Call Sari about the proposal")
    # The to-dos page lists the open follow-up with what, when, and the deal.
    |> click_link("To-dos")
    |> assert_has("h1", text: "To-dos")
    |> assert_has("#todo-list", text: "Call Sari about the proposal")
    |> assert_has("#todo-list", text: due_display)
    |> assert_has("#todo-list a", text: "Website redesign")
    |> refute_has("#todo-list", text: "Overdue")
    # The row links through to the deal…
    |> click_link("Website redesign")
    |> assert_has("h1", text: "Website redesign")
    # …and the follow-up can be marked done from the to-dos page.
    |> click_link("To-dos")
    |> within("#todo-list", fn session ->
      session
      |> click_button("Mark done")
    end)
    |> assert_has("#flash-info", text: "Follow-up completed.")
    |> refute_has("#todo-list", text: "Call Sari about the proposal")
    # Back on the deal, the completed follow-up stays visible…
    |> visit("/deals/#{deal.id}")
    |> assert_has("#deal-next-actions", text: "0 open")
    |> assert_has(".next-action-row", count: 1)
    |> assert_has(".next-action-row", text: "Call Sari about the proposal")
    # …and both follow-up lines sit in the log, newest first.
    |> assert_has(".activity-row", count: 3)
    |> assert_has(".activity-row",
      at: 1,
      text: "Follow-up completed: Call Sari about the proposal"
    )
    |> assert_has(".activity-row", at: 2, text: "Follow-up added: Call Sari about the proposal")
    |> assert_has(".activity-row", at: 3, text: "Deal created")
  end

  test "to-dos are soonest due first with overdue called out, and a deal can mark one done",
       %{conn: conn} do
    account = register!("sari@example.com")
    contact = contact!(account, "Sari Wijaya")

    deal =
      deal!(account, contact, %{
        title: "Website redesign",
        amount: 15_000_000,
        pipeline_column_id: column("Lead").id
      })

    {:ok, overdue} =
      NextActions.create_for_deal(deal, %{
        what: "Call about the overdue invoice",
        due_date: Date.add(Date.utc_today(), -1)
      })

    {:ok, _later} =
      NextActions.create_for_deal(deal, %{
        what: "Send the revised proposal",
        due_date: Date.add(Date.utc_today(), 10)
      })

    conn
    |> log_in_as("sari@example.com")
    |> visit("/todos")
    |> assert_has(".next-action-row", count: 2)
    # Soonest due first: the overdue one leads, and only it is called out.
    |> assert_has(".next-action-row", at: 1, text: "Call about the overdue invoice")
    |> assert_has(".next-action-row", at: 1, text: "Overdue")
    |> assert_has(".next-action-row", at: 2, text: "Send the revised proposal")
    |> refute_has(".next-action-row", at: 2, text: "Overdue")
    # The deal page calls the overdue one out too, and can complete it there.
    |> visit("/deals/#{deal.id}")
    |> assert_has(".next-action-row", count: 2)
    |> assert_has(".next-action-row", at: 1, text: "Overdue")
    |> within("#next-action-#{overdue.id}", fn session ->
      session
      |> click_button("Mark done")
    end)
    |> assert_has("#flash-info", text: "Follow-up completed.")
    |> assert_has("#deal-next-actions", text: "1 open")
    # Completing it removed it from the to-dos page.
    |> visit("/todos")
    |> assert_has(".next-action-row", count: 1)
    |> assert_has(".next-action-row", text: "Send the revised proposal")
    |> refute_has("#todo-list", text: "Call about the overdue invoice")
  end

  test "an account's to-dos never list another account's follow-ups", %{conn: conn} do
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

    budi_deal =
      deal!(budi, budi_contact, %{
        title: "Budi's proposal",
        amount: 25_000_000,
        pipeline_column_id: column("Lead").id
      })

    {:ok, _sari_action} =
      NextActions.create_for_deal(sari_deal, %{
        what: "private details only Sari should see",
        due_date: Date.add(Date.utc_today(), 1)
      })

    {:ok, _budi_action} =
      NextActions.create_for_deal(budi_deal, %{
        what: "Budi's own follow-up",
        due_date: Date.add(Date.utc_today(), 1)
      })

    conn
    |> log_in_as("budi@example.com")
    |> visit("/todos")
    |> assert_has("#todo-list", text: "Budi's own follow-up")
    |> assert_has("#todo-list a", text: "Budi's proposal")
    |> refute_has("main", text: "private details only Sari should see")
  end
end
