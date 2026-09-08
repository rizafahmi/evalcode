defmodule AlurWeb.Api.DealController do
  use AlurWeb, :controller

  alias Alur.Deals

  def index(conn, _params) do
    deals = conn.assigns.current_scope |> Deals.list_pipeline_deals()
    json(conn, %{deals: Enum.map(deals, &deal_json/1)})
  end

  def show(conn, %{"id" => id}) do
    case Deals.get_deal(conn.assigns.current_scope, id) do
      nil -> send_resp(conn, :not_found, "")
      deal -> json(conn, deal_json(deal))
    end
  end

  def update(conn, %{"id" => id, "pipeline_column_id" => column_id}) do
    scope = conn.assigns.current_scope

    with deal when not is_nil(deal) <- Deals.get_deal(scope, id),
         true <- not is_nil(Deals.get_pipeline_column(column_id)),
         {:ok, _moved} <- Deals.move_deal(scope, deal, column_id) do
      json(conn, deal_json(Deals.get_deal(scope, id)))
    else
      nil ->
        send_resp(conn, :not_found, "")

      false ->
        json(conn |> put_status(:unprocessable_entity), %{error: "invalid pipeline column"})

      {:error, :not_found} ->
        send_resp(conn, :not_found, "")
    end
  end

  def update(conn, _params) do
    json(conn |> put_status(:unprocessable_entity), %{error: "pipeline_column_id is required"})
  end

  defp deal_json(deal) do
    %{
      id: deal.id,
      title: deal.title,
      amount: deal.amount,
      pipeline_column_id: deal.pipeline_column_id,
      contact: %{id: deal.contact.id, name: deal.contact.name}
    }
  end
end
