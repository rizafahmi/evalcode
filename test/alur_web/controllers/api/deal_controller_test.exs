defmodule AlurWeb.Api.DealControllerTest do
  use AlurWeb.ConnCase

  alias Alur.Accounts.Scope
  alias Alur.AccountsFixtures
  alias Alur.Contacts
  alias Alur.Deals

  test "deal endpoints require an authenticated session", %{conn: conn} do
    assert response(get(conn, ~p"/api/deals"), 401) =~ "unauthorized"
  end

  test "lists and shows account-owned deals", %{conn: conn} do
    %{conn: conn, scope: scope} = register_and_log_in_user(%{conn: conn})
    {:ok, contact} = Contacts.create_contact(scope, %{name: "Ada Lovelace"})

    {:ok, deal} =
      Deals.create_deal(scope, %{
        title: "Website redesign",
        amount: 15_000_000,
        contact_id: contact.id,
        pipeline_column_id: "lead"
      })

    response = json_response(get(conn, ~p"/api/deals"), 200)

    assert [
             %{
               "id" => id,
               "pipeline_column_id" => "lead",
               "contact" => %{"name" => "Ada Lovelace"}
             }
           ] = response["deals"]

    assert id == deal.id
    assert json_response(get(conn, ~p"/api/deals/#{deal.id}"), 200)["title"] == "Website redesign"
  end

  test "deals and moves are isolated between accounts", %{conn: _conn} do
    first_user = AccountsFixtures.user_fixture()
    first_scope = Scope.for_user(first_user)
    {:ok, contact} = Contacts.create_contact(first_scope, %{name: "Private contact"})

    {:ok, deal} =
      Deals.create_deal(first_scope, %{
        title: "Private deal",
        amount: 100,
        contact_id: contact.id,
        pipeline_column_id: "lead"
      })

    %{conn: other_conn} = register_and_log_in_user(%{conn: build_conn()})
    assert response(get(other_conn, ~p"/api/deals/#{deal.id}"), 404) == ""

    assert response(
             patch(other_conn, ~p"/api/deals/#{deal.id}", %{pipeline_column_id: "meeting"}),
             404
           ) == ""
  end

  test "patching a deal uses the existing move operation", %{conn: conn} do
    %{conn: conn, scope: scope} = register_and_log_in_user(%{conn: conn})
    {:ok, contact} = Contacts.create_contact(scope, %{name: "Grace Hopper"})

    {:ok, deal} =
      Deals.create_deal(scope, %{
        title: "Compiler project",
        amount: 100,
        contact_id: contact.id,
        pipeline_column_id: "lead"
      })

    assert json_response(
             patch(conn, ~p"/api/deals/#{deal.id}", %{pipeline_column_id: "meeting"}),
             200
           )["pipeline_column_id"] == "meeting"

    assert Deals.get_deal(scope, deal.id).pipeline_column_id == "meeting"

    assert Enum.any?(
             Deals.list_deal_activities(scope, deal.id),
             &(&1.description == "Moved from Lead to Meeting.")
           )
  end
end
