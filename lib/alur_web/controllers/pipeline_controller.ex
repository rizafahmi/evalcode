defmodule AlurWeb.PipelineController do
  use AlurWeb, :controller

  alias Alur.Deals
  alias AlurWeb.DealJSON

  @doc """
  Returns the pipeline board aggregate with columns and deals for the authenticated user.
  """
  def index(conn, _params) do
    scope = conn.assigns.current_scope
    board = Deals.get_pipeline_board(scope)

    columns =
      Enum.map(board, fn %{column: col, deals: deals, total_amount: total_amount, count: count} ->
        %{
          id: col.id,
          name: col.name,
          order: col.order,
          total_amount: total_amount,
          count: count,
          deals: Enum.map(deals, &DealJSON.data/1)
        }
      end)

    json(conn, %{columns: columns})
  end
end
