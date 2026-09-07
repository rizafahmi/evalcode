defmodule Alur.Deals do
  @moduledoc """
  The Deals context.

  All operations on deals require an authenticated `Scope` as the first argument,
  ensuring strict isolation between user accounts.
  """

  import Ecto.Query, warn: false
  alias Alur.Accounts.Scope
  alias Alur.Accounts.User
  alias Alur.Activities
  alias Alur.Contacts
  alias Alur.Contacts.Contact
  alias Alur.Deals.Currency
  alias Alur.Deals.Deal
  alias Alur.Deals.PipelineColumn
  alias Alur.Repo

  defdelegate format_idr(amount), to: Currency

  @default_columns [
    %{id: "0191c78a-0001-7000-8000-000000000001", name: "Lead", order: 1},
    %{id: "0191c78a-0002-7000-8000-000000000002", name: "Meeting", order: 2},
    %{id: "0191c78a-0003-7000-8000-000000000003", name: "Proposal", order: 3},
    %{id: "0191c78a-0004-7000-8000-000000000004", name: "Won", order: 4},
    %{id: "0191c78a-0005-7000-8000-000000000005", name: "Lost", order: 5}
  ]

  ## Pipeline Columns

  @doc """
  Returns the list of pipeline columns, ordered by position (order ascending).
  """
  def list_pipeline_columns do
    from(c in PipelineColumn, order_by: [asc: c.order])
    |> Repo.all()
  end

  @doc """
  Gets a single pipeline column by ID.
  """
  def get_pipeline_column!(id) do
    Repo.get!(PipelineColumn, id)
  end

  @doc """
  Gets a single pipeline column by name.
  """
  def get_pipeline_column_by_name(name) do
    Repo.get_by(PipelineColumn, name: name)
  end

  @doc """
  Returns the default starting column ("Lead").
  """
  def default_pipeline_column do
    from(c in PipelineColumn, order_by: [asc: c.order], limit: 1)
    |> Repo.one!()
  end

  @doc """
  Seeds the default 5 pipeline columns if they are not already in the database.
  """
  def seed_pipeline_columns do
    for col <- @default_columns do
      case Repo.get(PipelineColumn, col.id) do
        nil ->
          %PipelineColumn{}
          |> PipelineColumn.changeset(col)
          |> Repo.insert(on_conflict: :nothing)

        _ ->
          :ok
      end
    end

    :ok
  end

  ## Deals

  @doc """
  Returns the list of deals belonging to the scoped user.
  """
  def list_deals(%Scope{user: %User{id: user_id}}, _params \\ %{}) do
    from(d in Deal,
      where: d.user_id == ^user_id,
      preload: [:contact, :pipeline_column],
      order_by: [desc: d.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Returns the list of deals for a given contact belonging to the scoped user.
  """
  def list_deals_for_contact(%Scope{user: %User{id: user_id}}, contact_or_id) do
    contact_id = extract_contact_id(contact_or_id)

    from(d in Deal,
      where: d.user_id == ^user_id and d.contact_id == ^contact_id,
      preload: [:contact, :pipeline_column],
      order_by: [desc: d.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Gets a single deal for the scoped user.
  Raises `Ecto.NoResultsError` if the deal does not exist or does not belong to the user.
  """
  def get_deal!(%Scope{user: %User{id: user_id}}, id) do
    from(d in Deal,
      where: d.id == ^id and d.user_id == ^user_id,
      preload: [:contact, :pipeline_column]
    )
    |> Repo.one!()
  end

  @doc """
  Gets a single deal for the scoped user, returning `{:ok, deal}` or `{:error, :not_found}`.
  """
  def get_deal(%Scope{user: %User{id: user_id}}, id) do
    deal =
      from(d in Deal,
        where: d.id == ^id and d.user_id == ^user_id,
        preload: [:contact, :pipeline_column]
      )
      |> Repo.one()

    case deal do
      nil -> {:error, :not_found}
      %Deal{} = found -> {:ok, found}
    end
  end

  @doc """
  Creates a deal belonging to the scoped user.
  Validates that the associated contact belongs to the same user.
  """
  def create_deal(%Scope{user: %User{id: user_id}} = scope, attrs) do
    contact_id = Map.get(attrs, "contact_id") || Map.get(attrs, :contact_id)

    case validate_contact_ownership(scope, contact_id) do
      :ok ->
        attrs = maybe_apply_default_column(attrs)
        insert_deal_with_activity(scope, user_id, attrs)

      {:error, reason} ->
        changeset =
          %Deal{user_id: user_id}
          |> Deal.changeset(attrs)
          |> Ecto.Changeset.add_error(:contact_id, reason)

        {:error, changeset}
    end
  end

  @doc """
  Updates a deal belonging to the scoped user.
  Validates contact ownership if `contact_id` is modified.
  """
  def update_deal(
        %Scope{user: %User{id: user_id}} = scope,
        %Deal{user_id: user_id} = deal,
        attrs
      ) do
    new_contact_id = Map.get(attrs, "contact_id") || Map.get(attrs, :contact_id)

    case validate_contact_ownership_on_update(scope, deal.contact_id, new_contact_id) do
      :ok ->
        deal
        |> Deal.changeset(attrs)
        |> Repo.update()
        |> preload_deal_associations()

      {:error, reason} ->
        changeset =
          deal
          |> Deal.changeset(attrs)
          |> Ecto.Changeset.add_error(:contact_id, reason)

        {:error, changeset}
    end
  end

  @doc """
  Returns pipeline columns with their deals for the scoped user.
  Each column map contains:
  - `:column` -> %PipelineColumn{}
  - `:deals` -> list of %Deal{} with :contact and :pipeline_column preloaded
  - `:total_amount` -> integer sum of deal amounts in this column
  - `:count` -> integer count of deals in this column
  """
  def get_pipeline_board(%Scope{} = scope) do
    columns = list_pipeline_columns()
    deals = list_deals(scope)

    deals_by_column = Enum.group_by(deals, & &1.pipeline_column_id)

    Enum.map(columns, fn column ->
      column_deals = Map.get(deals_by_column, column.id, [])
      total_amount = Enum.reduce(column_deals, 0, fn deal, acc -> acc + deal.amount end)

      %{
        column: column,
        deals: column_deals,
        total_amount: total_amount,
        count: length(column_deals)
      }
    end)
  end

  @doc """
  Moves a deal to a new pipeline column (stage).
  Accepts either a `%Deal{}` struct or a binary `deal_id`.
  Accepts either a `%PipelineColumn{}` struct, a binary column ID, or a column name.
  """
  def move_deal(
        %Scope{user: %User{id: user_id}} = scope,
        %Deal{user_id: user_id} = deal,
        %PipelineColumn{} = column
      ) do
    old_column_id = deal.pipeline_column_id
    new_column_id = column.id

    if old_column_id == new_column_id do
      preload_deal_associations({:ok, deal})
    else
      execute_deal_move(scope, deal, old_column_id, column)
    end
  end

  def move_deal(
        %Scope{user: %User{id: user_id}} = scope,
        %Deal{user_id: user_id} = deal,
        column_id_or_name
      )
      when is_binary(column_id_or_name) do
    column =
      Repo.get(PipelineColumn, column_id_or_name) ||
        get_pipeline_column_by_name(column_id_or_name)

    case column do
      nil -> {:error, :invalid_column}
      %PipelineColumn{} = col -> move_deal(scope, deal, col)
    end
  end

  def move_deal(%Scope{} = scope, deal_id, column_target) when is_binary(deal_id) do
    case get_deal(scope, deal_id) do
      {:ok, deal} -> move_deal(scope, deal, column_target)
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  def move_deal(%Scope{}, %Deal{}, _column_target) do
    {:error, :unauthorized}
  end

  @doc """
  Updates a deal's pipeline column (stage).
  Delegates to `move_deal/3`.
  """
  def change_deal_stage(%Scope{} = scope, deal_or_id, pipeline_column_id) do
    move_deal(scope, deal_or_id, pipeline_column_id)
  end

  @doc """
  Deletes a deal if it belongs to the scoped user.
  """
  def delete_deal(%Scope{user: %User{id: user_id}}, %Deal{user_id: user_id} = deal) do
    Repo.delete(deal)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking deal changes.
  """
  def change_deal(%Scope{}, %Deal{} = deal, attrs \\ %{}) do
    Deal.changeset(deal, attrs)
  end

  ## Private Helpers

  defp extract_contact_id(%Contact{id: id}), do: id
  defp extract_contact_id(id) when is_binary(id), do: id
  defp extract_contact_id(_), do: nil

  defp maybe_apply_default_column(attrs) when is_map(attrs) do
    has_col =
      Map.has_key?(attrs, "pipeline_column_id") or Map.has_key?(attrs, :pipeline_column_id)

    if has_col do
      attrs
    else
      default_col = default_pipeline_column()

      if Enum.any?(Map.keys(attrs), &is_atom/1) do
        Map.put(attrs, :pipeline_column_id, default_col.id)
      else
        Map.put(attrs, "pipeline_column_id", default_col.id)
      end
    end
  end

  defp validate_contact_ownership(_scope, nil), do: {:error, "can't be blank"}

  defp validate_contact_ownership(scope, contact_id) do
    case Contacts.get_contact(scope, contact_id) do
      {:ok, _contact} -> :ok
      {:error, :not_found} -> {:error, "is invalid"}
    end
  end

  defp validate_contact_ownership_on_update(_scope, _current_id, nil), do: :ok

  defp validate_contact_ownership_on_update(_scope, current_id, new_id)
       when current_id == new_id,
       do: :ok

  defp validate_contact_ownership_on_update(scope, _current_id, new_id) do
    validate_contact_ownership(scope, new_id)
  end

  defp preload_deal_associations({:ok, deal}) do
    {:ok, Repo.preload(deal, [:contact, :pipeline_column], force: true)}
  end

  defp preload_deal_associations({:error, changeset}), do: {:error, changeset}

  defp insert_deal_with_activity(scope, user_id, attrs) do
    Repo.transaction(fn ->
      with {:ok, deal} <- %Deal{user_id: user_id} |> Deal.changeset(attrs) |> Repo.insert(),
           {:ok, deal} <- preload_deal_associations({:ok, deal}),
           {:ok, _activity} <- Activities.log_deal_created(scope, deal) do
        deal
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  defp execute_deal_move(scope, deal, old_column_id, new_column) do
    Repo.transaction(fn ->
      case update_deal(scope, deal, %{pipeline_column_id: new_column.id}) do
        {:ok, updated_deal} ->
          old_column = deal.pipeline_column || Repo.get(PipelineColumn, old_column_id)
          _ = Activities.log_deal_moved(scope, updated_deal, old_column, new_column)
          updated_deal

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end
end
