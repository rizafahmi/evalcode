defmodule AlurWeb.TodoLiveTest do
  use AlurWeb.ConnCase

  import Phoenix.LiveViewTest
  alias Alur.Accounts.Scope
  alias Alur.AccountsFixtures
  alias Alur.DealsFixtures
  alias Alur.NextActionsFixtures

  setup do
    user = AccountsFixtures.user_fixture()
    scope = Scope.for_user(user)
    %{user: user, scope: scope}
  end

  test "redirects unauthenticated visitor to login", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/todos")
    assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/to-dos")
  end

  test "displays empty state when user has no pending to-dos", %{conn: conn, user: user} do
    {:ok, _lv, html} =
      conn
      |> log_in_user(user)
      |> live(~p"/todos")

    assert html =~ "To-dos"
    assert html =~ "No pending to-dos"
    assert html =~ "0 actions"
  end

  test "lists open actions across deals with what, when, and deal link, soonest due first", %{
    conn: conn,
    user: user,
    scope: scope
  } do
    deal_1 = DealsFixtures.deal_fixture(scope, %{title: "Big Retail Deal"})
    deal_2 = DealsFixtures.deal_fixture(scope, %{title: "SaaS Enterprise Contract"})

    date_1 = Date.utc_today() |> Date.add(5)
    date_2 = Date.utc_today() |> Date.add(1)

    act_1 =
      NextActionsFixtures.next_action_fixture(scope, deal_1, %{
        what: "Send proposal v2",
        due_date: date_1
      })

    act_2 =
      NextActionsFixtures.next_action_fixture(scope, deal_2, %{
        what: "Call legal team",
        due_date: date_2,
        due_time: ~T[10:00:00]
      })

    {:ok, _lv, html} =
      conn
      |> log_in_user(user)
      |> live(~p"/todos")

    assert html =~ "2 actions"
    assert html =~ "Send proposal v2"
    assert html =~ "Call legal team"
    assert html =~ "Big Retail Deal"
    assert html =~ "SaaS Enterprise Contract"
    assert html =~ ~p"/deals/#{deal_1.id}"
    assert html =~ ~p"/deals/#{deal_2.id}"

    # Soonest due (act_2, +1 day) should appear before act_1 (+5 days)
    pos_2 = :binary.match(html, act_2.what) |> elem(0)
    pos_1 = :binary.match(html, act_1.what) |> elem(0)
    assert pos_2 < pos_1
  end

  test "calls out overdue items visually", %{conn: conn, user: user, scope: scope} do
    deal = DealsFixtures.deal_fixture(scope, %{title: "Urgent Renewal"})
    past_date = Date.utc_today() |> Date.add(-2)

    _overdue_action =
      NextActionsFixtures.next_action_fixture(scope, deal, %{
        what: "Overdue review",
        due_date: past_date
      })

    {:ok, _lv, html} =
      conn
      |> log_in_user(user)
      |> live(~p"/todos")

    assert html =~ "Overdue review"
    assert html =~ "Overdue"
  end

  test "marks an action done directly from the to-dos page", %{
    conn: conn,
    user: user,
    scope: scope
  } do
    deal = DealsFixtures.deal_fixture(scope, %{title: "Direct Action Deal"})
    action = NextActionsFixtures.next_action_fixture(scope, deal, %{what: "Quick follow-up"})

    conn = log_in_user(conn, user)
    {:ok, lv, html} = live(conn, ~p"/todos")

    assert html =~ "Quick follow-up"
    assert html =~ "1 action"

    html =
      lv
      |> element("#todo-#{action.id} button", "Mark done")
      |> render_click()

    assert html =~ "Follow-up marked as completed."
    refute html =~ "Quick follow-up"
    assert html =~ "No pending to-dos"
  end

  test "multi-tenant: does not display actions belonging to another account", %{
    conn: conn,
    user: user
  } do
    other_user = AccountsFixtures.user_fixture()
    other_scope = Scope.for_user(other_user)
    other_deal = DealsFixtures.deal_fixture(other_scope, %{title: "Other User Deal"})

    _other_action =
      NextActionsFixtures.next_action_fixture(other_scope, other_deal, %{
        what: "Confidential task"
      })

    {:ok, _lv, html} =
      conn
      |> log_in_user(user)
      |> live(~p"/todos")

    refute html =~ "Confidential task"
    refute html =~ "Other User Deal"
  end

  test "supports /to-dos alternative URL alias", %{conn: conn, user: user} do
    {:ok, _lv, html} =
      conn
      |> log_in_user(user)
      |> live(~p"/to-dos")

    assert html =~ "To-dos"
  end
end
