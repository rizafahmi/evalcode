defmodule AlurWeb.Features.NextActionsTest do
  use AlurWeb.ConnCase

  alias Alur.Accounts.Scope
  alias Alur.AccountsFixtures
  alias Alur.ContactsFixtures
  alias Alur.Deals
  alias Alur.DealsFixtures

  test "complete next actions flow: add follow-up on deal, see on To-do page with deal name, overdue called out, mark done from either place, and matching activity log lines",
       %{conn: conn} do
    user = AccountsFixtures.user_fixture()
    scope = Scope.for_user(user)

    contact =
      ContactsFixtures.contact_fixture(scope, %{name: "Dewi Lestari", company: "Nusantara Cloud"})

    proposal_col = Deals.get_pipeline_column_by_name("Proposal")

    deal =
      DealsFixtures.deal_fixture(scope, %{
        title: "Multi-Cloud Migration",
        amount: 85_000_000,
        contact_id: contact.id,
        pipeline_column_id: proposal_col.id
      })

    past_date = Date.utc_today() |> Date.add(-2) |> Date.to_iso8601()
    future_date = Date.utc_today() |> Date.add(4) |> Date.to_iso8601()

    session =
      conn
      |> log_in_user(user)
      |> visit(~p"/deals/#{deal.id}")
      |> assert_has("h1", text: "Multi-Cloud Migration")
      |> assert_has("h2", text: "Next Actions")
      |> assert_has("h2", text: "Activity Log")

    # 1. Add an overdue follow-up on the deal
    session =
      session
      |> fill_in("What to do", with: "Submit compliance assessment")
      |> fill_in("Due date", with: past_date)
      |> click_button("Add follow-up")
      |> assert_has("[role=alert]", text: "Follow-up action scheduled.")
      |> assert_has("#incomplete-actions-list", text: "Submit compliance assessment")
      |> assert_has("#incomplete-actions-list", text: "Overdue")
      |> assert_has("#activity-log-stream",
        text: "Added next action: Submit compliance assessment"
      )

    # 2. Add a future follow-up with optional time on the deal
    session =
      session
      |> fill_in("What to do", with: "Finalize migration timeline")
      |> fill_in("Due date", with: future_date)
      |> fill_in("Time (optional)", with: "14:00")
      |> click_button("Add follow-up")
      |> assert_has("[role=alert]", text: "Follow-up action scheduled.")
      |> assert_has("#incomplete-actions-list", text: "Finalize migration timeline")
      |> assert_has("#activity-log-stream",
        text: "Added next action: Finalize migration timeline"
      )

    # 3. Visit To-do page: see actions with deal name, overdue called out
    session =
      session
      |> visit(~p"/todos")
      |> assert_has("h1", text: "To-dos")
      |> assert_has("#todos-list", text: "Submit compliance assessment")
      |> assert_has("#todos-list", text: "Finalize migration timeline")
      |> assert_has("#todos-list", text: "Multi-Cloud Migration")
      |> assert_has("#todos-list", text: "Overdue")

    # 4. Click through to deal from To-do page
    session =
      session
      |> within("#todos-list > div:first-child", fn el ->
        click_link(el, "Multi-Cloud Migration")
      end)
      |> assert_has("h1", text: "Multi-Cloud Migration")

    # 5. Mark done from deal page (mark "Submit compliance assessment" done)
    session =
      session
      |> visit(~p"/deals/#{deal.id}")
      |> within("#incomplete-actions-list > div:first-child", fn el ->
        click_button(el, "Mark done")
      end)
      |> assert_has("[role=alert]", text: "Follow-up marked as completed.")
      # Completed action stays visible on the deal
      |> assert_has("#completed-actions-list", text: "Submit compliance assessment")
      # Activity log contains completion line
      |> assert_has("#activity-log-stream",
        text: "Completed next action: Submit compliance assessment"
      )

    # 6. Return to To-do page: only the remaining incomplete action is shown
    session =
      session
      |> visit(~p"/todos")
      |> refute_has("#todos-list", text: "Submit compliance assessment")
      |> assert_has("#todos-list", text: "Finalize migration timeline")

    # 7. Mark done from To-do page
    session =
      session
      |> click_button("Mark done")
      |> assert_has("[role=alert]", text: "Follow-up marked as completed.")
      |> assert_has("h3", text: "No pending to-dos")

    # 8. Revisit deal page: both completed actions stay visible and activity stream has both completion lines
    _session =
      session
      |> visit(~p"/deals/#{deal.id}")
      |> assert_has("#completed-actions-list", text: "Submit compliance assessment")
      |> assert_has("#completed-actions-list", text: "Finalize migration timeline")
      |> assert_has("#activity-log-stream",
        text: "Completed next action: Submit compliance assessment"
      )
      |> assert_has("#activity-log-stream",
        text: "Completed next action: Finalize migration timeline"
      )

    # 9. Multi-tenant isolation: another user account has clean state
    other_user = AccountsFixtures.user_fixture()

    conn
    |> log_in_user(other_user)
    |> visit(~p"/todos")
    |> assert_has("h3", text: "No pending to-dos")
    |> refute_has("body", text: "Multi-Cloud Migration")
  end
end
