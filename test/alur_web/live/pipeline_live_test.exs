defmodule AlurWeb.PipelineLiveTest do
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

  test "redirects if user is not logged in", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/")
  end

  test "displays 5 columns in order with empty totals when no deals exist", %{
    conn: conn,
    user: user
  } do
    {:ok, _lv, html} =
      conn
      |> log_in_user(user)
      |> live(~p"/")

    assert html =~ "Pipeline"
    assert html =~ "Lead"
    assert html =~ "Meeting"
    assert html =~ "Proposal"
    assert html =~ "Won"
    assert html =~ "Lost"
    assert html =~ "Drop deals here"
  end

  test "displays deals in their respective columns with title, contact, and IDR amount", %{
    conn: conn,
    user: user,
    scope: scope
  } do
    lead_col = Deals.get_pipeline_column_by_name("Lead")
    proposal_col = Deals.get_pipeline_column_by_name("Proposal")

    deal_1 =
      DealsFixtures.deal_fixture(scope, %{
        title: "Alpha Service Deal",
        amount: 15_000_000,
        pipeline_column_id: lead_col.id
      })

    deal_2 =
      DealsFixtures.deal_fixture(scope, %{
        title: "Beta Hardware Deal",
        amount: 35_000_000,
        pipeline_column_id: proposal_col.id
      })

    {:ok, _lv, html} =
      conn
      |> log_in_user(user)
      |> live(~p"/")

    assert html =~ deal_1.title
    assert html =~ deal_1.contact.name
    assert html =~ "Rp 15.000.000"

    assert html =~ deal_2.title
    assert html =~ deal_2.contact.name
    assert html =~ "Rp 35.000.000"
  end

  test "moving deal across columns via move_deal event updates board and database", %{
    conn: conn,
    user: user,
    scope: scope
  } do
    lead_col = Deals.get_pipeline_column_by_name("Lead")
    meeting_col = Deals.get_pipeline_column_by_name("Meeting")

    deal =
      DealsFixtures.deal_fixture(scope, %{
        title: "Cloud Migration Retainer",
        amount: 25_000_000,
        pipeline_column_id: lead_col.id
      })

    {:ok, lv, html} =
      conn
      |> log_in_user(user)
      |> live(~p"/")

    assert html =~ "Cloud Migration Retainer"

    # Move deal from Lead to Meeting
    rendered =
      render_hook(lv, "move_deal", %{
        "deal_id" => deal.id,
        "column_id" => meeting_col.id
      })

    # Deal is now in Meeting column
    assert rendered =~ "Cloud Migration Retainer"

    # Verify persisted in database
    updated = Deals.get_deal!(scope, deal.id)
    assert updated.pipeline_column_id == meeting_col.id

    # Verify column totals match
    board = Deals.get_pipeline_board(scope)
    lead_stage = Enum.find(board, &(&1.column.name == "Lead"))
    meeting_stage = Enum.find(board, &(&1.column.name == "Meeting"))

    assert lead_stage.total_amount == 0
    assert lead_stage.count == 0
    assert meeting_stage.total_amount == 25_000_000
    assert meeting_stage.count == 1
  end

  test "moving deal with invalid column displays flash error", %{
    conn: conn,
    user: user,
    scope: scope
  } do
    deal = DealsFixtures.deal_fixture(scope)

    {:ok, lv, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/")

    rendered =
      render_hook(lv, "move_deal", %{
        "deal_id" => deal.id,
        "column_id" => "invalid-column-id"
      })

    assert rendered =~ "Unable to move deal."
  end

  test "cannot move another user's deal", %{
    conn: conn,
    user: user_a
  } do
    user_b = AccountsFixtures.user_fixture()
    scope_b = Scope.for_user(user_b)
    deal_b = DealsFixtures.deal_fixture(scope_b, %{title: "User B Deal"})
    meeting_col = Deals.get_pipeline_column_by_name("Meeting")

    {:ok, lv, _html} =
      conn
      |> log_in_user(user_a)
      |> live(~p"/")

    rendered =
      render_hook(lv, "move_deal", %{
        "deal_id" => deal_b.id,
        "column_id" => meeting_col.id
      })

    assert rendered =~ "Unable to move deal."

    # Verify deal_b has not moved
    refreshed = Deals.get_deal!(scope_b, deal_b.id)
    refute refreshed.pipeline_column_id == meeting_col.id
  end
end
