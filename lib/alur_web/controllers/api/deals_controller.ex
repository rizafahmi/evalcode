defmodule AlurWeb.Api.DealsController do
  @moduledoc """
  The account-scoped JSON API that powers the Vue Kanban at `/app`
  (milestone 8).

  Every action reads the signed-in account from `conn.assigns.current_scope`
  (set by the `:api_authenticated` pipeline, which answered `401` when nobody
  is signed in), so one account can never list, read, or move another
  account's deals — reads that miss go `404`, exactly like the LiveView pages.

  Moves go through `Alur.Deals.move_deal/3`, the same choke point board drags
  on the LiveView Pipeline use, so activity-log move lines keep firing.
  """

  use AlurWeb, :controller

  alias Alur.Deals
  alias Alur.Deals.Deal

  @doc """
  `GET /api/deals` — every deal of the signed-in account, newest first.
  """
  def index(conn, _params) do
    deals =
      conn.assigns.current_scope
      |> Deals.list_deals()
      |> Enum.map(&deal_json/1)

    json(conn, %{deals: deals})
  end

  @doc """
  `GET /api/deals/:id` — one deal of the signed-in account, or `404` when the
  id is unknown or belongs to another account.
  """
  def show(conn, %{"id" => id}) do
    case Deals.get_deal(conn.assigns.current_scope, id) do
      %Deal{} = deal -> json(conn, %{deal: deal_json(deal)})
      nil -> not_found(conn)
    end
  end

  @doc """
  `PATCH /api/deals/:id` — moves a deal to another pipeline column.

  The JSON body carries `pipeline_column_id`; the move is resolved
  account-scoped through `Alur.Deals.move_deal/3` so activity-log move lines
  from milestone 5 still fire. Unknown or foreign deals and unknown target
  columns answer `404`; a missing or invalid body answers `422`.
  """
  def update(conn, %{"id" => id} = params) do
    case params["pipeline_column_id"] do
      nil ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: %{pipeline_column_id: ["is required"]}})

      pipeline_column_id ->
        case Deals.move_deal(conn.assigns.current_scope, id, pipeline_column_id) do
          {:ok, %Deal{} = deal} ->
            json(conn, %{deal: deal_json(deal)})

          {:error, :not_found} ->
            not_found(conn)

          {:error, %Ecto.Changeset{} = _changeset} ->
            # Only the column is changed here and the target column was
            # already resolved by move_deal, so this is effectively
            # unreachable; answer 422 rather than crashing.
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{errors: %{detail: "Invalid deal update"}})
        end
    end
  end

  @doc """
  `GET /api/pipeline` — the board aggregate the Vue app needs to render a
  column with its own deal cards: the five fixed pipeline columns in board
  order (each with its id, which `/api/deals` does not return) plus every deal
  of the signed-in account. Column totals are derived client-side from the
  deal amounts, so they always match the cards.
  """
  def pipeline(conn, _params) do
    account = conn.assigns.current_scope

    columns =
      Deals.list_pipeline_columns()
      |> Enum.map(fn column ->
        %{id: column.id, name: column.name, order: column.order}
      end)

    deals =
      account
      |> Deals.list_deals()
      |> Enum.map(&deal_json/1)

    json(conn, %{columns: columns, deals: deals})
  end

  # The JSON shape a deal is served as. The deal's contact is preloaded by
  # every Deals fetch, so the card has everything the Kanban renders: title,
  # rupiah amount, column, and contact name.
  defp deal_json(%Deal{} = deal) do
    %{
      id: deal.id,
      title: deal.title,
      amount: deal.amount,
      pipeline_column_id: deal.pipeline_column_id,
      contact: %{id: deal.contact.id, name: deal.contact.name}
    }
  end

  defp not_found(conn) do
    conn
    |> put_status(:not_found)
    |> json(%{errors: %{detail: "Not Found"}})
  end
end
