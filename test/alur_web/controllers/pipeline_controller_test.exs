defmodule AlurWeb.PipelineControllerTest do
  use AlurWeb.ConnCase

  import Alur.AccountsFixtures
  import Alur.DealsFixtures

  alias Alur.Accounts.Scope
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

  describe "GET /api/pipeline" do
    test "returns 401 when unauthenticated", %{conn: conn} do
      conn = get(conn, ~p"/api/pipeline")
      assert json_response(conn, 401) == %{"error" => "unauthorized"}
    end

    test "returns board aggregate with columns and deals for authenticated user", %{
      conn: conn,
      user: user,
      scope: scope,
      other_scope: other_scope,
      lead_col: lead_col
    } do
      deal =
        deal_fixture(scope, %{
          title: "Board Deal",
          amount: 20_000_000,
          pipeline_column_id: lead_col.id
        })

      _other_deal = deal_fixture(other_scope, %{title: "Other Board Deal", amount: 50_000_000})

      conn =
        conn
        |> log_in_user(user)
        |> get(~p"/api/pipeline")

      assert %{"columns" => columns} = json_response(conn, 200)
      assert length(columns) == 5

      lead_data = Enum.find(columns, &(&1["name"] == "Lead"))
      assert lead_data["id"] == lead_col.id
      assert lead_data["count"] == 1
      assert lead_data["total_amount"] == 20_000_000
      assert length(lead_data["deals"]) == 1
      assert hd(lead_data["deals"])["id"] == deal.id

      meeting_data = Enum.find(columns, &(&1["name"] == "Meeting"))
      assert meeting_data["count"] == 0
      assert meeting_data["total_amount"] == 0
      assert meeting_data["deals"] == []
    end
  end
end
