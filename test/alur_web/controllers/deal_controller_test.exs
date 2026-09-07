defmodule AlurWeb.DealControllerTest do
  use AlurWeb.ConnCase

  import Alur.AccountsFixtures
  import Alur.DealsFixtures

  alias Alur.Accounts.Scope
  alias Alur.Activities
  alias Alur.Deals

  setup do
    user = user_fixture()
    scope = Scope.for_user(user)

    other_user = user_fixture()
    other_scope = Scope.for_user(other_user)

    columns = Deals.list_pipeline_columns()
    lead_col = Enum.find(columns, &(&1.name == "Lead"))
    meeting_col = Enum.find(columns, &(&1.name == "Meeting"))

    %{
      user: user,
      scope: scope,
      other_user: other_user,
      other_scope: other_scope,
      lead_col: lead_col,
      meeting_col: meeting_col
    }
  end

  describe "GET /api/deals" do
    test "returns 401 when unauthenticated", %{conn: conn} do
      conn = get(conn, ~p"/api/deals")
      assert json_response(conn, 401) == %{"error" => "unauthorized"}
    end

    test "returns account-scoped deals for authenticated user", %{
      conn: conn,
      user: user,
      scope: scope,
      other_scope: other_scope,
      lead_col: lead_col
    } do
      user_deal = deal_fixture(scope, %{title: "My User Deal", pipeline_column_id: lead_col.id})
      _other_deal = deal_fixture(other_scope, %{title: "Other User Deal"})

      conn =
        conn
        |> log_in_user(user)
        |> get(~p"/api/deals")

      assert deals = json_response(conn, 200)
      assert is_list(deals)
      assert length(deals) == 1

      [returned_deal] = deals
      assert returned_deal["id"] == user_deal.id
      assert returned_deal["title"] == "My User Deal"
      assert returned_deal["pipeline_column_id"] == lead_col.id
      assert returned_deal["amount"] == 15_000_000
      assert returned_deal["contact"]["id"] == user_deal.contact_id
      assert returned_deal["contact"]["name"] == user_deal.contact.name
    end
  end

  describe "GET /api/deals/:id" do
    test "returns 401 when unauthenticated", %{conn: conn, scope: scope} do
      deal = deal_fixture(scope)
      conn = get(conn, ~p"/api/deals/#{deal.id}")
      assert json_response(conn, 401) == %{"error" => "unauthorized"}
    end

    test "returns deal details for the owner", %{
      conn: conn,
      user: user,
      scope: scope,
      lead_col: lead_col
    } do
      deal = deal_fixture(scope, %{title: "Big Opportunity", pipeline_column_id: lead_col.id})

      conn =
        conn
        |> log_in_user(user)
        |> get(~p"/api/deals/#{deal.id}")

      assert data = json_response(conn, 200)
      assert data["id"] == deal.id
      assert data["title"] == "Big Opportunity"
      assert data["pipeline_column_id"] == lead_col.id
      assert data["contact"]["name"] == deal.contact.name
    end

    test "returns 404 for deal belonging to another user (isolation)", %{
      conn: conn,
      user: user,
      other_scope: other_scope
    } do
      other_deal = deal_fixture(other_scope)

      conn =
        conn
        |> log_in_user(user)
        |> get(~p"/api/deals/#{other_deal.id}")

      assert json_response(conn, 404) == %{"error" => "not_found"}
    end

    test "returns 404 for non-existent deal", %{conn: conn, user: user} do
      non_existent_id = Ecto.UUID.generate()

      conn =
        conn
        |> log_in_user(user)
        |> get(~p"/api/deals/#{non_existent_id}")

      assert json_response(conn, 404) == %{"error" => "not_found"}
    end
  end

  describe "PATCH /api/deals/:id" do
    test "returns 401 when unauthenticated", %{
      conn: conn,
      scope: scope,
      meeting_col: meeting_col
    } do
      deal = deal_fixture(scope)

      conn =
        patch(conn, ~p"/api/deals/#{deal.id}", %{
          pipeline_column_id: meeting_col.id
        })

      assert json_response(conn, 401) == %{"error" => "unauthorized"}
    end

    test "updates deal column and records activity log move line", %{
      conn: conn,
      user: user,
      scope: scope,
      lead_col: lead_col,
      meeting_col: meeting_col
    } do
      deal = deal_fixture(scope, %{pipeline_column_id: lead_col.id})

      conn =
        conn
        |> log_in_user(user)
        |> patch(~p"/api/deals/#{deal.id}", %{
          pipeline_column_id: meeting_col.id
        })

      assert response = json_response(conn, 200)
      assert response["id"] == deal.id
      assert response["pipeline_column_id"] == meeting_col.id

      # Verify persistence in database
      reloaded = Deals.get_deal!(scope, deal.id)
      assert reloaded.pipeline_column_id == meeting_col.id

      # Verify activity log move line was logged
      activities = Activities.list_activities_for_deal(scope, deal.id)

      assert Enum.any?(activities, fn a ->
               a.action_type == "moved" and a.description == "Moved to Meeting"
             end)
    end

    test "supports wrapped parameter body", %{
      conn: conn,
      user: user,
      scope: scope,
      lead_col: lead_col,
      meeting_col: meeting_col
    } do
      deal = deal_fixture(scope, %{pipeline_column_id: lead_col.id})

      conn =
        conn
        |> log_in_user(user)
        |> patch(~p"/api/deals/#{deal.id}", %{
          "deal" => %{"pipeline_column_id" => meeting_col.id}
        })

      assert response = json_response(conn, 200)
      assert response["pipeline_column_id"] == meeting_col.id
    end

    test "returns 404 when attempting to move another user's deal", %{
      conn: conn,
      user: user,
      other_scope: other_scope,
      meeting_col: meeting_col
    } do
      other_deal = deal_fixture(other_scope)

      conn =
        conn
        |> log_in_user(user)
        |> patch(~p"/api/deals/#{other_deal.id}", %{
          pipeline_column_id: meeting_col.id
        })

      assert json_response(conn, 404) == %{"error" => "not_found"}
    end

    test "returns 422 when pipeline_column_id is missing", %{
      conn: conn,
      user: user,
      scope: scope
    } do
      deal = deal_fixture(scope)

      conn =
        conn
        |> log_in_user(user)
        |> patch(~p"/api/deals/#{deal.id}", %{})

      assert json_response(conn, 422) == %{"error" => "pipeline_column_id is required"}
    end

    test "returns 422 when pipeline_column_id is invalid", %{
      conn: conn,
      user: user,
      scope: scope
    } do
      deal = deal_fixture(scope)
      fake_id = Ecto.UUID.generate()

      conn =
        conn
        |> log_in_user(user)
        |> patch(~p"/api/deals/#{deal.id}", %{
          pipeline_column_id: fake_id
        })

      assert json_response(conn, 422) == %{"error" => "invalid_column"}
    end
  end
end
