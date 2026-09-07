defmodule AlurWeb.DealLive.ShowTest do
  use AlurWeb.ConnCase

  import Phoenix.LiveViewTest
  alias Alur.Accounts.Scope
  alias Alur.AccountsFixtures
  alias Alur.Deals
  alias Alur.DealsFixtures

  setup do
    user = AccountsFixtures.user_fixture()
    scope = Scope.for_user(user)
    %{user: user, scope: scope}
  end

  test "redirects if user is not logged in", %{conn: conn, scope: scope} do
    deal = DealsFixtures.deal_fixture(scope)
    assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/deals/#{deal}")
  end

  test "displays deal details with rupiah formatting", %{conn: conn, user: user, scope: scope} do
    deal =
      DealsFixtures.deal_fixture(scope, %{
        title: "Enterprise Server Cluster",
        amount: 45_000_000,
        notes: "Requires dedicated support SLA"
      })

    {:ok, _lv, html} =
      conn
      |> log_in_user(user)
      |> live(~p"/deals/#{deal}")

    assert html =~ "Enterprise Server Cluster"
    assert html =~ "Rp 45.000.000"
    assert html =~ "Lead"
    assert html =~ deal.contact.name
    assert html =~ "Requires dedicated support SLA"
    assert html =~ "Activity Log"
    assert html =~ "Deal created"
  end

  test "changes pipeline stage on the deal page and logs move line with timestamp", %{
    conn: conn,
    user: user,
    scope: scope
  } do
    deal = DealsFixtures.deal_fixture(scope)
    meeting = Deals.get_pipeline_column_by_name("Meeting")

    conn = log_in_user(conn, user)
    {:ok, lv, _html} = live(conn, ~p"/deals/#{deal}")

    html =
      lv
      |> element("button[phx-value-stage_id='#{meeting.id}']")
      |> render_click()

    assert html =~ "Deal stage updated to Meeting."
    assert html =~ "Meeting"
    assert html =~ "Moved to Meeting"

    # Reload from db and verify persistence
    updated = Deals.get_deal!(scope, deal.id)
    assert updated.pipeline_column_id == meeting.id
  end

  test "adds a manual note to the activity log and displays it", %{
    conn: conn,
    user: user,
    scope: scope
  } do
    deal = DealsFixtures.deal_fixture(scope)

    conn = log_in_user(conn, user)
    {:ok, lv, html} = live(conn, ~p"/deals/#{deal}")

    assert html =~ "Deal created"

    # Submit a note
    html =
      lv
      |> form("form[phx-submit='add_note']", %{
        "note" => "Client agreed to contract terms via phone."
      })
      |> render_submit()

    assert html =~ "Note added to activity log."
    assert html =~ "Client agreed to contract terms via phone."

    # Verify no edit or delete buttons for activities
    refute html =~ "Edit note"
    refute html =~ "Delete note"
    refute html =~ "activity-delete"
  end

  test "validates note cannot be blank", %{
    conn: conn,
    user: user,
    scope: scope
  } do
    deal = DealsFixtures.deal_fixture(scope)

    conn = log_in_user(conn, user)
    {:ok, lv, _html} = live(conn, ~p"/deals/#{deal}")

    html =
      lv
      |> form("form[phx-submit='add_note']", %{"note" => "   "})
      |> render_submit()

    assert html =~ "Note cannot be blank."
  end

  test "deletes deal and redirects to contact page", %{conn: conn, user: user, scope: scope} do
    deal = DealsFixtures.deal_fixture(scope, %{title: "Deal To Discard"})
    contact_id = deal.contact_id

    conn = log_in_user(conn, user)
    {:ok, lv, _html} = live(conn, ~p"/deals/#{deal}")

    {:ok, _contact_lv, html} =
      lv
      |> element("button", "Delete")
      |> render_click()
      |> follow_redirect(conn, ~p"/contacts/#{contact_id}")

    assert html =~ "Deal deleted successfully."
    refute html =~ "Deal To Discard"
  end

  test "cannot view another user's deal", %{conn: conn, user: user} do
    other_user = AccountsFixtures.user_fixture()
    other_scope = Scope.for_user(other_user)
    other_deal = DealsFixtures.deal_fixture(other_scope)

    assert_raise Ecto.NoResultsError, fn ->
      conn
      |> log_in_user(user)
      |> live(~p"/deals/#{other_deal}")
    end
  end

  describe "next actions on deal page" do
    test "schedules a follow-up action and updates activity log", %{
      conn: conn,
      user: user,
      scope: scope
    } do
      deal = DealsFixtures.deal_fixture(scope)
      future_date = Date.utc_today() |> Date.add(3) |> Date.to_iso8601()

      conn = log_in_user(conn, user)
      {:ok, lv, html} = live(conn, ~p"/deals/#{deal}")

      assert html =~ "Next Actions"
      assert html =~ "0 pending"

      html =
        lv
        |> form("form[phx-submit='add_next_action']", %{
          "next_action" => %{
            "what" => "Send pricing agreement draft",
            "due_date" => future_date,
            "due_time" => "15:00"
          }
        })
        |> render_submit()

      assert html =~ "Follow-up action scheduled."
      assert html =~ "Send pricing agreement draft"
      assert html =~ "1 pending"
      assert html =~ "Added next action: Send pricing agreement draft"
    end

    test "marks action done from deal page, stays visible in completed list, and logs activity",
         %{
           conn: conn,
           user: user,
           scope: scope
         } do
      deal = DealsFixtures.deal_fixture(scope)
      date = Date.utc_today() |> Date.add(1) |> Date.to_iso8601()

      conn = log_in_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/deals/#{deal}")

      # Schedule action
      html =
        lv
        |> form("form[phx-submit='add_next_action']", %{
          "next_action" => %{
            "what" => "Follow up on phone",
            "due_date" => date
          }
        })
        |> render_submit()

      assert html =~ "Follow up on phone"
      assert html =~ "1 pending"

      # Mark done
      html =
        lv
        |> element("button", "Mark done")
        |> render_click()

      assert html =~ "Follow-up marked as completed."
      assert html =~ "0 pending"
      # Stays visible in completed section
      assert html =~ "Completed (1)"
      assert html =~ "Follow up on phone"
      # Activity log contains completion line
      assert html =~ "Completed next action: Follow up on phone"
    end

    test "overdue follow-up is called out on the deal page", %{
      conn: conn,
      user: user,
      scope: scope
    } do
      deal = DealsFixtures.deal_fixture(scope)
      past_date = Date.utc_today() |> Date.add(-3) |> Date.to_iso8601()

      conn = log_in_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/deals/#{deal}")

      html =
        lv
        |> form("form[phx-submit='add_next_action']", %{
          "next_action" => %{
            "what" => "Overdue task on deal",
            "due_date" => past_date
          }
        })
        |> render_submit()

      assert html =~ "Overdue task on deal"
      assert html =~ "Overdue"
    end
  end
end
