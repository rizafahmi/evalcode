defmodule AlurWeb.DealController do
  use AlurWeb, :controller

  alias Alur.Deals
  alias AlurWeb.DealJSON

  @doc """
  Returns all deals belonging to the authenticated user.
  """
  def index(conn, _params) do
    deals = Deals.list_deals(conn.assigns.current_scope)
    json(conn, DealJSON.index(%{deals: deals}))
  end

  @doc """
  Returns a single deal belonging to the authenticated user.
  Returns 404 if the deal does not exist or belongs to another user.
  """
  def show(conn, %{"id" => id}) do
    case Deals.get_deal(conn.assigns.current_scope, id) do
      {:ok, deal} ->
        json(conn, DealJSON.show(%{deal: deal}))

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found"})
    end
  end

  @doc """
  Updates a deal's pipeline column stage via `Alur.Deals.move_deal/3`.
  Preserves activity log move lines.
  """
  def update(conn, %{"id" => id} = params) do
    pipeline_column_id =
      Map.get(params, "pipeline_column_id") ||
        get_in(params, ["deal", "pipeline_column_id"])

    if is_nil(pipeline_column_id) or pipeline_column_id == "" do
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{error: "pipeline_column_id is required"})
    else
      scope = conn.assigns.current_scope

      case Deals.move_deal(scope, id, pipeline_column_id) do
        {:ok, updated_deal} ->
          json(conn, DealJSON.show(%{deal: updated_deal}))

        {:error, :not_found} ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "not_found"})

        {:error, :unauthorized} ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "not_found"})

        {:error, :invalid_column} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: "invalid_column"})

        {:error, %Ecto.Changeset{} = changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{errors: translate_errors(changeset)})
      end
    end
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
