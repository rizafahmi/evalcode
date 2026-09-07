defmodule AlurWeb.Api.DealsControllerTest do
  use AlurWeb.ConnCase, async: false

  alias Alur.Accounts
  alias Alur.Activities
  alias Alur.Contacts
  alias Alur.Deals
  alias Alur.Deals.Deal

  @password "super secret 1234"

  defp account!(attrs \\ %{}) do
    email = attrs[:email] || "owner-#{System.unique_integer([:positive])}@example.com"

    {:ok, account} =
      Accounts.register_account(%{
        email: email,
        password: @password,
        password_confirmation: @password
      })

    account
  end

  defp contact!(account, attrs \\ %{}) do
    {:ok, contact} = Contacts.create_contact(account, Map.merge(%{name: "Sari Wijaya"}, attrs))
    contact
  end

  defp column!(name) do
    Enum.find(Deals.list_pipeline_columns(), &(&1.name == name))
  end

  defp deal!(account, attrs \\ []) do
    {:ok, deal} =
      Deals.create_deal(
        account,
        contact!(account),
        Enum.into(attrs, %{
          title: "Website redesign",
          amount: 15_000_000,
          pipeline_column_id: column!("Lead").id
        })
      )

    deal
  end

  # Sign in over the real HTML log-in form so the connection carries the
  # browser session cookie the JSON API authenticates with.
  defp session_conn(%Accounts.Account{} = account) do
    build_conn()
    |> post(~p"/accounts/log-in", account: %{email: account.email, password: @password})
    |> recycle()
  end

  # Send a body as actual JSON (not urlencoded) the way the Vue app does.
  defp patch_json(conn, path, body) do
    conn
    |> put_req_header("content-type", "application/json")
    |> patch(path, Jason.encode!(body))
  end

  describe "GET /api/deals" do
    test "answers 401 for a logged-out visitor" do
      conn = get(build_conn(), ~p"/api/deals")

      assert conn.status == 401
      assert %{"errors" => %{"detail" => _}} = json_response(conn, 401)
    end

    test "lists only the signed-in account's deals, newest first, with the card fields" do
      account = account!()

      {:ok, _older} =
        Deals.create_deal(account, contact!(account), %{
          title: "Older",
          amount: 10_000_000,
          pipeline_column_id: column!("Lead").id
        })

      Process.sleep(1100)

      {:ok, newer} =
        Deals.create_deal(account, contact!(account), %{
          title: "Newer",
          amount: 25_000_000,
          pipeline_column_id: column!("Meeting").id
        })

      other = account!()

      {:ok, _foreign} =
        Deals.create_deal(other, contact!(other), %{
          title: "Not yours",
          amount: 5_000_000,
          pipeline_column_id: column!("Lead").id
        })

      conn = get(session_conn(account), ~p"/api/deals")

      assert %{"deals" => [%{"title" => "Newer"}, %{"title" => "Older"}]} =
               json_response(conn, 200)

      [newer_json | _] = json_response(conn, 200)["deals"]

      assert newer_json["id"] == newer.id
      assert newer_json["pipeline_column_id"] == column!("Meeting").id
      assert newer_json["amount"] == 25_000_000
      assert %{"name" => "Sari Wijaya"} = newer_json["contact"]

      # The other account's deals never leak into this list.
      refute Enum.any?(json_response(conn, 200)["deals"], &(&1["title"] == "Not yours"))
    end
  end

  describe "GET /api/deals/:id" do
    test "answers 401 for a logged-out visitor" do
      conn = get(build_conn(), ~p"/api/deals/00000000-0000-0000-0000-000000000000")

      assert conn.status == 401
    end

    test "returns the deal of the signed-in account" do
      account = account!()
      deal = deal!(account, title: "Website redesign")

      conn = get(session_conn(account), ~p"/api/deals/#{deal.id}")

      assert %{"deal" => deal_json} = json_response(conn, 200)
      assert deal_json["id"] == deal.id
      assert deal_json["title"] == "Website redesign"
      assert deal_json["pipeline_column_id"] == column!("Lead").id
      assert deal_json["contact"]["name"] == "Sari Wijaya"
    end

    test "answers 404 for an unknown id and for another account's deal" do
      account = account!()
      deal = deal!(account)
      other = account!()

      assert get(session_conn(account), ~p"/api/deals/#{Ecto.UUID.generate()}").status ==
               404

      assert get(session_conn(other), ~p"/api/deals/#{deal.id}").status == 404
    end
  end

  describe "PATCH /api/deals/:id" do
    test "answers 401 for a logged-out visitor" do
      conn =
        patch_json(build_conn(), ~p"/api/deals/00000000-0000-0000-0000-000000000000", %{
          pipeline_column_id: Ecto.UUID.generate()
        })

      assert conn.status == 401
    end

    test "moves the deal through move_deal, persists, and returns the updated deal" do
      account = account!()
      deal = deal!(account)

      conn =
        session_conn(account)
        |> patch_json(~p"/api/deals/#{deal.id}", %{
          pipeline_column_id: column!("Meeting").id
        })

      assert %{"deal" => %{"id" => id, "pipeline_column_id" => meeting}} =
               json_response(conn, 200)

      assert id == deal.id
      assert meeting == column!("Meeting").id

      # The move really persisted…
      assert %Deal{pipeline_column: %{name: "Meeting"}} =
               Deals.get_deal(account, deal.id)

      # …and went through move_deal, so the activity-log move line fired.
      assert Enum.map(Activities.list_for_deal(deal), & &1.description) == [
               "Moved from Lead to Meeting",
               "Deal created"
             ]
    end

    test "moving onto the column the deal is already on is a harmless 200" do
      account = account!()
      deal = deal!(account)

      conn =
        session_conn(account)
        |> patch_json(~p"/api/deals/#{deal.id}", %{
          pipeline_column_id: column!("Lead").id
        })

      assert %{"deal" => %{"pipeline_column_id" => lead}} = json_response(conn, 200)
      assert lead == column!("Lead").id
      assert Enum.map(Activities.list_for_deal(deal), & &1.description) == ["Deal created"]
    end

    test "answers 404 for a foreign deal or an unknown target column, leaving the deal alone" do
      account = account!()
      deal = deal!(account)
      other = account!()

      foreign =
        session_conn(other)
        |> patch_json(~p"/api/deals/#{deal.id}", %{
          pipeline_column_id: column!("Meeting").id
        })

      assert foreign.status == 404

      unknown_column =
        session_conn(account)
        |> patch_json(~p"/api/deals/#{deal.id}", %{
          pipeline_column_id: Ecto.UUID.generate()
        })

      assert unknown_column.status == 404

      assert %Deal{pipeline_column: %{name: "Lead"}} = Deals.get_deal(account, deal.id)
      assert Enum.map(Activities.list_for_deal(deal), & &1.description) == ["Deal created"]
    end

    test "answers 422 when the body omits pipeline_column_id" do
      account = account!()
      deal = deal!(account)

      conn = session_conn(account) |> patch_json(~p"/api/deals/#{deal.id}", %{})

      assert conn.status == 422
      assert %{"errors" => %{"pipeline_column_id" => _}} = json_response(conn, 422)
    end
  end

  describe "GET /api/pipeline" do
    test "answers 401 for a logged-out visitor" do
      assert get(build_conn(), ~p"/api/pipeline").status == 401
    end

    test "returns the five columns in board order with ids plus the account's deals" do
      account = account!()

      {:ok, lead_deal} =
        Deals.create_deal(account, contact!(account), %{
          title: "Website redesign",
          amount: 15_000_000,
          pipeline_column_id: column!("Lead").id
        })

      conn = get(session_conn(account), ~p"/api/pipeline")

      assert %{"columns" => columns, "deals" => deals} = json_response(conn, 200)

      assert Enum.map(columns, & &1["name"]) == ["Lead", "Meeting", "Proposal", "Won", "Lost"]
      assert Enum.map(columns, & &1["order"]) == [1, 2, 3, 4, 5]
      assert Enum.all?(columns, &is_binary(&1["id"]))

      assert [%{"id" => id, "pipeline_column_id" => column_id}] = deals
      assert id == lead_deal.id
      assert column_id == column!("Lead").id
    end

    test "never includes another account's deals" do
      account = account!()
      deal!(account)
      other = account!()
      deal!(other, title: "Not yours")

      conn = get(session_conn(account), ~p"/api/pipeline")

      assert json_response(conn, 200)["deals"]
             |> Enum.map(& &1["title"]) == ["Website redesign"]
    end
  end
end
