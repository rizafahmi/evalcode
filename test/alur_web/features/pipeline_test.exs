defmodule AlurWeb.PipelineFeatureTest do
  use AlurWeb.ConnCase, async: false

  alias Alur.Accounts
  alias Alur.Contacts
  alias Alur.Deals
  alias Alur.Deals.Deal
  alias Phoenix.LiveViewTest

  @password "super secret 1234"

  defp register!(email) do
    {:ok, account} =
      Accounts.register_account(%{
        email: email,
        password: @password,
        password_confirmation: @password
      })

    account
  end

  defp contact!(account, name) do
    {:ok, contact} = Contacts.create_contact(account, %{name: name})
    contact
  end

  defp deal!(account, contact, attrs) do
    {:ok, deal} = Deals.create_deal(account, contact, attrs)
    deal
  end

  defp column(name) do
    Enum.find(Deals.list_pipeline_columns(), &(&1.name == name))
  end

  defp log_in_as(conn, email) do
    conn
    |> visit("/accounts/log-in")
    |> fill_in("Email", with: email)
    |> fill_in("Password", with: @password)
    |> click_button("Log in")
  end

  test "the board lists every deal on its column with totals, moves survive a refresh, and cards open deals",
       %{conn: conn} do
    account = register!("puri@example.com")
    contact = contact!(account, "Sari Wijaya")

    lead_deal =
      deal!(account, contact, %{
        title: "Website redesign",
        amount: 15_000_000,
        pipeline_column_id: column("Lead").id
      })

    deal!(account, contact, %{
      title: "Logo refresh",
      amount: 20_000_000,
      pipeline_column_id: column("Lead").id
    })

    deal!(account, contact, %{
      title: "Onboarding retainer",
      amount: 10_000_000,
      pipeline_column_id: column("Meeting").id
    })

    conn
    |> log_in_as("puri@example.com")
    |> assert_has("h1", text: "Deal pipeline")
    |> unwrap(fn view ->
      # The five columns render left to right: Lead → Meeting → Proposal → Won → Lost.
      html = LiveViewTest.render(view)

      positions =
        Enum.map(["Lead", "Meeting", "Proposal", "Won", "Lost"], fn name ->
          case :binary.match(html, ~s(id="pipeline-column-#{column(name).id}")) do
            {position, _length} -> position
            :nomatch -> -1
          end
        end)

      assert positions == Enum.sort(positions), "columns are not rendered in board order"
      html
    end)
    # Every existing deal is a card on its own column, with title, contact, and rupiah value.
    |> assert_has("#pipeline-column-#{column("Lead").id}", text: "Website redesign")
    |> assert_has("#pipeline-column-#{column("Lead").id}", text: "Logo refresh")
    |> assert_has("#pipeline-column-#{column("Meeting").id}", text: "Onboarding retainer")
    |> assert_has("#pipeline-column-#{column("Proposal").id}", text: "No deals")
    |> assert_has("#deal-card-#{lead_deal.id}", text: "Sari Wijaya")
    |> assert_has("#deal-card-#{lead_deal.id}", text: "Rp 15.000.000")
    # Column totals sum the cards in each column.
    |> assert_has("#pipeline-column-#{column("Lead").id}", text: "Rp 35.000.000")
    |> assert_has("#pipeline-column-#{column("Meeting").id}", text: "Rp 10.000.000")
    |> assert_has("#pipeline-column-#{column("Won").id}", text: "Rp 0")
    # "Dropping" the card on Meeting is the server event the drag hook sends.
    |> unwrap(fn view ->
      LiveViewTest.render_hook(view, "move_deal", %{
        "deal_id" => lead_deal.id,
        "column_id" => column("Meeting").id
      })
    end)
    |> assert_has("#pipeline-column-#{column("Meeting").id}", text: "Website redesign")
    |> assert_has("#pipeline-column-#{column("Lead").id}", text: "Rp 20.000.000")
    |> assert_has("#pipeline-column-#{column("Meeting").id}", text: "Rp 25.000.000")
    # Refreshing keeps the deal on the new column.
    |> reload_page()
    |> assert_has("#pipeline-column-#{column("Meeting").id}", text: "Website redesign")
    |> refute_has("#pipeline-column-#{column("Lead").id}", text: "Website redesign")
    # Clicking the card opens the deal page.
    |> click_link("Website redesign")
    |> assert_has("h1", text: "Website redesign")
    |> assert_has("main", text: "Meeting")
    |> assert_path("/deals/#{lead_deal.id}")
  end

  test "the board shows only the signed-in account's deals, and foreign moves are refused", %{
    conn: conn
  } do
    sari = register!("sari@example.com")
    budi = register!("budi@example.com")
    sari_contact = contact!(sari, "Sari Raharjo")
    budi_contact = contact!(budi, "Budi Santoso")

    sari_deal =
      deal!(sari, sari_contact, %{
        title: "Secret opportunity",
        amount: 50_000_000,
        pipeline_column_id: column("Lead").id
      })

    deal!(budi, budi_contact, %{
      title: "Budi's proposal",
      amount: 25_000_000,
      pipeline_column_id: column("Proposal").id
    })

    conn
    |> log_in_as("budi@example.com")
    |> assert_has("#pipeline-board", text: "Budi's proposal")
    |> refute_has("#pipeline-board", text: "Secret opportunity")
    |> refute_has("#deal-card-#{sari_deal.id}")
    |> assert_has("#pipeline-column-#{column("Lead").id}", text: "Rp 0")
    |> assert_has("#pipeline-column-#{column("Proposal").id}", text: "Rp 25.000.000")
    # Driving a move event with Sari's deal id does nothing: no crash, no move.
    |> unwrap(fn view ->
      LiveViewTest.render_hook(view, "move_deal", %{
        "deal_id" => sari_deal.id,
        "column_id" => column("Meeting").id
      })
    end)
    |> reload_page()
    |> refute_has("#pipeline-board", text: "Secret opportunity")

    assert %Deal{pipeline_column: %{name: "Lead"}} = Deals.get_deal(sari, sari_deal.id)
  end

  test "a fresh account sees the five empty columns and a create-a-deal hint", %{conn: conn} do
    register!("fresh@example.com")

    conn
    |> log_in_as("fresh@example.com")
    |> assert_has("h1", text: "Deal pipeline")
    |> assert_has("main", text: "No deals yet")
    |> assert_has("#pipeline-board .border-dashed", text: "No deals", count: 5)
  end
end
