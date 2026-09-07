defmodule AlurWeb.Features.PipelineTest do
  use AlurWeb.ConnCase

  import Phoenix.LiveViewTest
  alias Alur.Accounts.Scope
  alias Alur.AccountsFixtures
  alias Alur.ContactsFixtures
  alias Alur.Deals
  alias Alur.DealsFixtures

  test "Kanban pipeline: deals appear in correct columns, totals match cards, drag moves deal, persists on refresh, click opens deal",
       %{conn: conn} do
    user = AccountsFixtures.user_fixture()
    scope = Scope.for_user(user)

    contact_1 =
      ContactsFixtures.contact_fixture(scope, %{name: "Budi Santoso", company: "PT Maju Bersama"})

    contact_2 =
      ContactsFixtures.contact_fixture(scope, %{name: "Siti Rahma", company: "Nusantara Tech"})

    lead_col = Deals.get_pipeline_column_by_name("Lead")
    meeting_col = Deals.get_pipeline_column_by_name("Meeting")
    proposal_col = Deals.get_pipeline_column_by_name("Proposal")

    deal_lead =
      DealsFixtures.deal_fixture(scope, %{
        title: "Cloud Infrastructure Setup",
        amount: 20_000_000,
        contact_id: contact_1.id,
        pipeline_column_id: lead_col.id
      })

    _deal_meeting =
      DealsFixtures.deal_fixture(scope, %{
        title: "ERP Integration Consulting",
        amount: 45_000_000,
        contact_id: contact_2.id,
        pipeline_column_id: meeting_col.id
      })

    _deal_proposal =
      DealsFixtures.deal_fixture(scope, %{
        title: "Annual Maintenance Contract",
        amount: 10_000_000,
        contact_id: contact_1.id,
        pipeline_column_id: proposal_col.id
      })

    # 1. Existing deals appear on the board in the right columns with IDR totals
    session =
      conn
      |> log_in_user(user)
      |> visit(~p"/")
      |> assert_has("h1", text: "Pipeline")
      |> assert_has("#column-#{lead_col.id}", text: "Lead")
      |> assert_has("#column-#{lead_col.id}", text: "Cloud Infrastructure Setup")
      |> assert_has("#column-#{lead_col.id}", text: "Budi Santoso")
      |> assert_has("#column-#{lead_col.id}", text: "Rp 20.000.000")
      |> assert_has("#column-total-#{lead_col.id}", text: "Rp 20.000.000")
      |> assert_has("#column-#{meeting_col.id}", text: "Meeting")
      |> assert_has("#column-#{meeting_col.id}", text: "ERP Integration Consulting")
      |> assert_has("#column-#{meeting_col.id}", text: "Siti Rahma")
      |> assert_has("#column-#{meeting_col.id}", text: "Rp 45.000.000")
      |> assert_has("#column-total-#{meeting_col.id}", text: "Rp 45.000.000")
      |> assert_has("#column-#{proposal_col.id}", text: "Proposal")
      |> assert_has("#column-#{proposal_col.id}", text: "Annual Maintenance Contract")
      |> assert_has("#column-#{proposal_col.id}", text: "Budi Santoso")
      |> assert_has("#column-#{proposal_col.id}", text: "Rp 10.000.000")
      |> assert_has("#column-total-#{proposal_col.id}", text: "Rp 10.000.000")

    # 2. Drag a card from Lead to Meeting: column totals update
    session =
      session
      |> unwrap(fn view ->
        render_hook(view, "move_deal", %{
          "deal_id" => deal_lead.id,
          "column_id" => meeting_col.id
        })
      end)
      |> assert_has("#column-#{meeting_col.id}", text: "Cloud Infrastructure Setup")
      |> assert_has("#column-total-#{lead_col.id}", text: "Rp 0")
      |> assert_has("#column-total-#{meeting_col.id}", text: "Rp 65.000.000")
      |> refute_has("#column-#{lead_col.id}", text: "Cloud Infrastructure Setup")

    # 3. Refresh and verify the card stays in Meeting
    session =
      session
      |> visit(~p"/")
      |> assert_has("#column-#{meeting_col.id}", text: "Cloud Infrastructure Setup")
      |> assert_has("#column-total-#{meeting_col.id}", text: "Rp 65.000.000")
      |> assert_has("#column-total-#{lead_col.id}", text: "Rp 0")
      |> refute_has("#column-#{lead_col.id}", text: "Cloud Infrastructure Setup")

    # 4. Click a card to open the deal
    session
    |> click_link("Cloud Infrastructure Setup")
    |> assert_path(~p"/deals/#{deal_lead.id}")
    |> assert_has("h1", text: "Cloud Infrastructure Setup")
    |> assert_has("dd", text: "Rp 20.000.000")
    |> assert_has("span", text: "Meeting")
  end

  test "multi-tenant isolation: another user sees an empty board with zero totals", %{conn: conn} do
    user_a = AccountsFixtures.user_fixture()
    scope_a = Scope.for_user(user_a)

    _deal_a =
      DealsFixtures.deal_fixture(scope_a, %{
        title: "Confidential Strategy Project",
        amount: 80_000_000
      })

    user_b = AccountsFixtures.user_fixture()

    conn
    |> log_in_user(user_b)
    |> visit(~p"/")
    |> assert_has("h1", text: "Pipeline")
    |> refute_has("h3", text: "Confidential Strategy Project")
    |> refute_has("span", text: "Rp 80.000.000")
  end
end
