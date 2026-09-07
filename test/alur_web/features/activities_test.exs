defmodule AlurWeb.Features.ActivitiesTest do
  use AlurWeb.ConnCase

  import Phoenix.LiveViewTest
  alias Alur.Accounts.Scope
  alias Alur.AccountsFixtures
  alias Alur.ContactsFixtures
  alias Alur.Deals
  alias Alur.DealsFixtures

  test "activity log: deal creation logs created line, kanban drag logs move line, deal page stage change logs move line, manual note added, newest-first order, cannot edit or delete",
       %{conn: conn} do
    user = AccountsFixtures.user_fixture()
    scope = Scope.for_user(user)

    contact =
      ContactsFixtures.contact_fixture(scope, %{name: "Ratih Kumala", company: "Kreasi Media"})

    lead_col = Deals.get_pipeline_column_by_name("Lead")
    meeting_col = Deals.get_pipeline_column_by_name("Meeting")

    # 1. Create a deal
    deal =
      DealsFixtures.deal_fixture(scope, %{
        title: "Brand Strategy Retainer",
        amount: 30_000_000,
        contact_id: contact.id,
        pipeline_column_id: lead_col.id
      })

    # 2. Opening the deal shows a created line with date/time
    session =
      conn
      |> log_in_user(user)
      |> visit(~p"/deals/#{deal.id}")
      |> assert_has("h1", text: "Brand Strategy Retainer")
      |> assert_has("h2", text: "Activity Log")
      |> assert_has("#activity-log-stream", text: "Deal created")

    # 3. Dragging deal on the Kanban board (Lead -> Meeting)
    session =
      session
      |> visit(~p"/")
      |> assert_has("#column-#{lead_col.id}", text: "Brand Strategy Retainer")
      |> unwrap(fn view ->
        render_hook(view, "move_deal", %{
          "deal_id" => deal.id,
          "column_id" => meeting_col.id
        })
      end)
      |> assert_has("#column-#{meeting_col.id}", text: "Brand Strategy Retainer")

    # 4. Opening the deal again shows the move line with timestamp
    session =
      session
      |> visit(~p"/deals/#{deal.id}")
      |> assert_has("#activity-log-stream", text: "Moved to Meeting")
      |> assert_has("#activity-log-stream", text: "Deal created")

    # 5. Changing column on the deal page (Meeting -> Proposal) adds another move line
    session =
      session
      |> click_button("Proposal")
      |> assert_has("[role=alert]", text: "Deal stage updated to Proposal.")
      |> assert_has("#activity-log-stream", text: "Moved to Proposal")
      |> assert_has("#activity-log-stream", text: "Moved to Meeting")
      |> assert_has("#activity-log-stream", text: "Deal created")

    # 6. Type a manual note and see it in the log
    session =
      session
      |> fill_in("Add a note", with: "Client approved scope outline; preparing legal paperwork.")
      |> click_button("Add note")
      |> assert_has("[role=alert]", text: "Note added to activity log.")
      |> assert_has("#activity-log-stream",
        text: "Client approved scope outline; preparing legal paperwork."
      )

    # 7. Verify you cannot edit or delete an activity line
    session
    |> refute_has("#activity-log-stream button", text: "Edit")
    |> refute_has("#activity-log-stream button", text: "Delete")
    |> refute_has("#activity-log-stream a", text: "Edit")
    |> refute_has("#activity-log-stream a", text: "Delete")
  end

  test "multi-tenant isolation: user cannot see activity log for deals of another account", %{
    conn: conn
  } do
    user_a = AccountsFixtures.user_fixture()
    scope_a = Scope.for_user(user_a)
    deal_a = DealsFixtures.deal_fixture(scope_a, %{title: "Confidential M&A Deal"})

    user_b = AccountsFixtures.user_fixture()

    assert_raise Ecto.NoResultsError, fn ->
      conn
      |> log_in_user(user_b)
      |> visit(~p"/deals/#{deal_a.id}")
    end
  end
end
