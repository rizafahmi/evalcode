defmodule AlurWeb.Features.VueKanbanPipelineTest do
  use AlurWeb.ConnCase

  alias Alur.Accounts.Scope
  alias Alur.AccountsFixtures
  alias Alur.Activities
  alias Alur.ContactsFixtures
  alias Alur.Deals
  alias Alur.DealsFixtures

  setup do
    user = AccountsFixtures.user_fixture()
    scope = Scope.for_user(user)

    contact =
      ContactsFixtures.contact_fixture(scope, %{
        name: "Rian Hidayat",
        company: "PT Solusi Digital"
      })

    lead_col = Deals.get_pipeline_column_by_name("Lead")
    meeting_col = Deals.get_pipeline_column_by_name("Meeting")
    proposal_col = Deals.get_pipeline_column_by_name("Proposal")

    deal =
      DealsFixtures.deal_fixture(scope, %{
        title: "Enterprise Software License",
        amount: 35_000_000,
        contact_id: contact.id,
        pipeline_column_id: lead_col.id
      })

    %{
      user: user,
      scope: scope,
      contact: contact,
      lead_col: lead_col,
      meeting_col: meeting_col,
      proposal_col: proposal_col,
      deal: deal
    }
  end

  test "GET /app is authentication-protected and renders #app mount container in shell", %{
    conn: conn,
    user: user
  } do
    # 1. Unauthenticated -> redirected to login
    conn
    |> visit("/app")
    |> assert_path(~p"/users/log-in")
    |> assert_has("[role=alert]", text: "You must log in to access this page.")

    # 2. Authenticated -> renders page with #app mount container
    session =
      conn
      |> log_in_user(user)
      |> visit("/app")

    session
    |> assert_path("/app")
    |> assert_has("#app")
    |> assert_has("header")
    |> assert_has("a", text: "Alur")
    |> assert_has("nav a", text: "Pipeline")
    |> assert_has("nav a", text: "Contacts")
    |> assert_has("nav a", text: "To-dos")
    |> refute_has("nav a", text: "App")
  end

  test "REST API over session cookies: GET /api/deals, GET /api/pipeline, PATCH /api/deals/:id",
       %{
         conn: conn,
         user: user,
         scope: scope,
         deal: deal,
         lead_col: lead_col,
         meeting_col: meeting_col
       } do
    auth_conn = log_in_user(conn, user)

    # 1. GET /api/deals returns user's deals
    res_conn = get(auth_conn, ~p"/api/deals")
    assert deals = json_response(res_conn, 200)
    assert length(deals) == 1
    [deal_data] = deals
    assert deal_data["id"] == deal.id
    assert deal_data["title"] == "Enterprise Software License"
    assert deal_data["amount"] == 35_000_000
    assert deal_data["pipeline_column_id"] == lead_col.id
    assert deal_data["contact"]["name"] == "Rian Hidayat"

    # 2. GET /api/pipeline returns columns and aggregate
    res_conn = get(auth_conn, ~p"/api/pipeline")
    assert %{"columns" => columns} = json_response(res_conn, 200)
    assert length(columns) == 5

    lead_data = Enum.find(columns, &(&1["id"] == lead_col.id))
    assert lead_data["count"] == 1
    assert lead_data["total_amount"] == 35_000_000

    meeting_data = Enum.find(columns, &(&1["id"] == meeting_col.id))
    assert meeting_data["count"] == 0
    assert meeting_data["total_amount"] == 0

    # 3. PATCH /api/deals/:id moves deal from Lead to Meeting
    res_conn =
      patch(auth_conn, ~p"/api/deals/#{deal.id}", %{
        pipeline_column_id: meeting_col.id
      })

    assert updated = json_response(res_conn, 200)
    assert updated["id"] == deal.id
    assert updated["pipeline_column_id"] == meeting_col.id

    # 4. Verifies database persistence and activity log entry
    reloaded_deal = Deals.get_deal!(scope, deal.id)
    assert reloaded_deal.pipeline_column_id == meeting_col.id

    activities = Activities.list_activities_for_deal(scope, deal.id)

    assert Enum.any?(activities, fn a ->
             a.action_type == "moved" and a.description == "Moved to Meeting"
           end)

    # 5. Subsequent GET /api/pipeline reflects updated column totals
    res_conn = get(auth_conn, ~p"/api/pipeline")
    assert %{"columns" => updated_columns} = json_response(res_conn, 200)

    lead_data_after = Enum.find(updated_columns, &(&1["id"] == lead_col.id))
    assert lead_data_after["count"] == 0
    assert lead_data_after["total_amount"] == 0

    meeting_data_after = Enum.find(updated_columns, &(&1["id"] == meeting_col.id))
    assert meeting_data_after["count"] == 1
    assert meeting_data_after["total_amount"] == 35_000_000
  end

  test "multi-tenant isolation across REST endpoints", %{
    conn: conn,
    deal: deal,
    meeting_col: meeting_col
  } do
    other_user = AccountsFixtures.user_fixture()
    other_conn = log_in_user(conn, other_user)

    # Other user cannot see first user's deal
    res = get(other_conn, ~p"/api/deals")
    assert json_response(res, 200) == []

    # Other user cannot GET first user's deal
    res = get(other_conn, ~p"/api/deals/#{deal.id}")
    assert json_response(res, 404) == %{"error" => "not_found"}

    # Other user cannot PATCH first user's deal
    res =
      patch(other_conn, ~p"/api/deals/#{deal.id}", %{
        pipeline_column_id: meeting_col.id
      })

    assert json_response(res, 404) == %{"error" => "not_found"}
  end

  test "browser bundle verification: mounts on #app, renders columns, drags card, issues PATCH, refreshes with persistence" do
    {output, exit_code} = System.cmd("node", ["test/support/verify_vue_board.mjs"])
    assert exit_code == 0, "Verification script failed:\n#{output}"
    assert output =~ "Verification passed successfully"
  end
end
