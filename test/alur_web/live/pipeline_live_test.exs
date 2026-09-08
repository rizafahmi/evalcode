defmodule AlurWeb.PipelineLiveTest do
  use AlurWeb.ConnCase

  import Phoenix.LiveViewTest
  import Alur.AccountsFixtures

  setup %{conn: conn} do
    user = user_fixture()
    scope = user_scope_fixture(user)
    %{conn: log_in_user(conn, user), scope: scope}
  end

  test "renders deals in their columns with IDR totals and links", %{conn: conn, scope: scope} do
    {:ok, contact} = Alur.Contacts.create_contact(scope, %{name: "Ada Lovelace"})

    {:ok, deal} =
      Alur.Deals.create_deal(scope, %{
        title: "Website redesign",
        amount: 15_000_000,
        contact_id: contact.id,
        pipeline_column_id: "lead"
      })

    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "Lead"
    assert html =~ "Website redesign"
    assert html =~ "Ada Lovelace"
    assert html =~ "Rp 15.000.000"
    assert html =~ ~p"/deals/#{deal.id}"
    assert html =~ "1 active records"
  end

  test "moves a deal and keeps it in the new column", %{conn: conn, scope: scope} do
    {:ok, contact} = Alur.Contacts.create_contact(scope, %{name: "Grace Hopper"})

    {:ok, deal} =
      Alur.Deals.create_deal(scope, %{
        title: "Compiler contract",
        amount: 20_000,
        contact_id: contact.id,
        pipeline_column_id: "lead"
      })

    {:ok, view, _html} = live(conn, ~p"/")

    render_hook(view, "move-deal", %{
      "deal_id" => deal.id,
      "pipeline_column_id" => "meeting"
    })

    assert Alur.Deals.get_deal(scope, deal.id).pipeline_column.id == "meeting"
    assert render(view) =~ "pipeline-column-meeting"
  end

  test "does not show another account's deals", %{conn: conn} do
    other_scope = user_scope_fixture()
    {:ok, contact} = Alur.Contacts.create_contact(other_scope, %{name: "Private contact"})

    {:ok, _deal} =
      Alur.Deals.create_deal(other_scope, %{
        title: "Private opportunity",
        amount: 100,
        contact_id: contact.id,
        pipeline_column_id: "lead"
      })

    {:ok, _view, html} = live(conn, ~p"/")
    refute html =~ "Private opportunity"
  end
end
