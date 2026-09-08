defmodule Alur.Deals do
  @moduledoc "The Deals context."

  import Ecto.Query, warn: false
  import Ecto.Changeset, only: [add_error: 3]

  alias Alur.Accounts.Scope
  alias Alur.Contacts.Contact
  alias Alur.Deals.Activity
  alias Alur.Deals.Deal
  alias Alur.Deals.NextAction
  alias Alur.Deals.PipelineColumn
  alias Alur.Repo

  @jakarta_offset_seconds 7 * 60 * 60

  @doc "Lists the fixed pipeline columns in display order."
  def list_pipeline_columns,
    do: Repo.all(from column in PipelineColumn, order_by: column.position)

  @doc "Lists all deals belonging to the current account for the pipeline board."
  def list_pipeline_deals(%Scope{user: user}) do
    Deal
    |> where([deal], deal.user_id == ^user.id)
    |> preload([:contact, :pipeline_column])
    |> order_by([deal], asc: deal.inserted_at)
    |> Repo.all()
  end

  @doc "Gets a pipeline column by its fixed id."
  def get_pipeline_column(id), do: Repo.get(PipelineColumn, id)

  @doc "Lists deals belonging to the current account and contact."
  def list_contact_deals(%Scope{user: user}, contact_id) do
    Deal
    |> where([deal], deal.user_id == ^user.id and deal.contact_id == ^contact_id)
    |> preload(:pipeline_column)
    |> order_by([deal], desc: deal.inserted_at)
    |> Repo.all()
  end

  @doc "Gets a deal for the current account."
  def get_deal(%Scope{user: user}, id) do
    Deal
    |> where([deal], deal.id == ^id and deal.user_id == ^user.id)
    |> preload([:contact, :pipeline_column, :activities])
    |> Repo.one()
  end

  @doc "Lists immutable activity entries for an account-owned deal, newest first."
  def list_deal_activities(%Scope{user: user}, deal_id) do
    Activity
    |> join(:inner, [activity], deal in Deal, on: deal.id == activity.deal_id)
    |> where([activity, deal], activity.deal_id == ^deal_id and activity.user_id == ^user.id)
    |> order_by([activity], desc: activity.inserted_at, desc: activity.id)
    |> Repo.all()
  end

  @doc "Lists all open next actions for the current account, soonest first."
  def list_open_next_actions(%Scope{user: user}) do
    NextAction
    |> join(:inner, [action], deal in Deal, on: deal.id == action.deal_id)
    |> where(
      [action, deal],
      action.user_id == ^user.id and deal.user_id == ^user.id and not action.done
    )
    |> preload(:deal)
    |> order_by([action], asc: action.due, asc: action.id)
    |> Repo.all()
  end

  @doc "Lists all next actions for an account-owned deal, open first then due date."
  def list_deal_next_actions(%Scope{user: user}, deal_id) do
    NextAction
    |> where([action], action.user_id == ^user.id and action.deal_id == ^deal_id)
    |> order_by([action], asc: action.done, asc: action.due, asc: action.id)
    |> Repo.all()
  end

  @doc "Returns a changeset for a new follow-up, including date/time form fields."
  def change_next_action(%Scope{} = scope, %Deal{} = deal, attrs \\ %{}) do
    attrs = Map.new(attrs)
    due_date = Map.get(attrs, "due_date") || Map.get(attrs, :due_date)
    due_time = Map.get(attrs, "due_time") || Map.get(attrs, :due_time)

    %NextAction{user_id: scope.user.id, deal_id: deal.id}
    |> NextAction.changeset(Map.take(attrs, ["description", :description, "due", :due]))
    |> Ecto.Changeset.put_change(:due_date, due_date)
    |> Ecto.Changeset.put_change(:due_time, due_time)
  end

  @doc "Adds a follow-up and records it in the deal activity log."
  def create_next_action(%Scope{user: user}, %Deal{} = deal, attrs) do
    if deal.user_id == user.id,
      do: create_next_action_for_user(user, deal, Map.new(attrs)),
      else: {:error, :not_found}
  end

  @doc "Marks an account-owned follow-up complete and logs the completion."
  def complete_next_action(%Scope{user: user}, %NextAction{} = action) do
    if action.user_id == user.id and not action.done do
      Ecto.Multi.new()
      |> Ecto.Multi.update(:next_action, Ecto.Changeset.change(action, done: true))
      |> Ecto.Multi.insert(:activity, fn %{next_action: updated} ->
        %Activity{user_id: user.id, deal_id: updated.deal_id}
        |> Activity.changeset(%{description: "Follow-up completed: #{updated.description}."})
      end)
      |> Repo.transaction()
      |> case do
        {:ok, %{next_action: updated}} -> {:ok, updated}
        {:error, _operation, changeset, _changes} -> {:error, changeset}
      end
    else
      {:error, :not_found}
    end
  end

  @doc "Formats a follow-up due time in the product timezone."
  def format_next_action_due(%NextAction{due: due}) do
    local = DateTime.add(due, @jakarta_offset_seconds)
    date = Calendar.strftime(local, "%d %b %Y")
    time = Calendar.strftime(local, "%H:%M")
    if time == "23:59", do: date, else: "#{date} at #{time}"
  end

  @doc "Whether a follow-up is overdue in Asia/Jakarta."
  def overdue?(%NextAction{due: due, done: false}),
    do: DateTime.compare(due, DateTime.utc_now()) == :lt

  def overdue?(%NextAction{}), do: false

  @doc "Returns a changeset for a user-authored activity note."
  def change_activity(%Scope{user: user}, %Deal{} = deal),
    do: Activity.changeset(%Activity{user_id: user.id, deal_id: deal.id}, %{})

  @doc "Adds an immutable, account-scoped activity note to a deal."
  def create_activity(%Scope{user: user}, %Deal{} = deal, attrs) do
    if deal.user_id == user.id do
      %Activity{user_id: user.id, deal_id: deal.id}
      |> Activity.changeset(attrs)
      |> Repo.insert()
    else
      {:error, :not_found}
    end
  end

  @doc "Creates a deal for the current account when its contact is also owned by it."
  def create_deal(%Scope{user: user}, attrs) do
    with {:ok, contact_id} <- fetch_id(attrs, :contact_id),
         %Contact{} = contact <- Repo.get_by(Contact, id: contact_id, user_id: user.id),
         {:ok, pipeline_column_id} <- fetch_id(attrs, :pipeline_column_id),
         %PipelineColumn{} <- get_pipeline_column(pipeline_column_id) do
      deal_changeset = Deal.changeset(%Deal{user_id: user.id, contact_id: contact.id}, attrs)
      column = get_pipeline_column(pipeline_column_id)

      Ecto.Multi.new()
      |> Ecto.Multi.insert(:deal, deal_changeset)
      |> Ecto.Multi.run(:activity, fn repo, %{deal: deal} ->
        %Activity{user_id: user.id, deal_id: deal.id}
        |> Activity.changeset(%{description: "Deal created in #{column.name}."})
        |> repo.insert()
      end)
      |> Repo.transaction()
      |> handle_transaction_result()
    else
      nil -> {:error, :not_found}
      {:error, :missing} -> {:error, :not_found}
      _ -> {:error, :not_found}
    end
  end

  @doc "Returns a changeset for a deal."
  def change_deal(%Scope{} = scope, %Deal{} = deal),
    do: Deal.changeset(deal, %{}) |> put_contact_if_owned(scope, deal.contact_id)

  def change_deal(%Scope{} = scope, contact_id) do
    %Deal{contact_id: contact_id, pipeline_column_id: "lead"}
    |> Deal.changeset(%{})
    |> put_contact_if_owned(scope, contact_id)
  end

  @doc "Updates a deal belonging to the current account."
  def update_deal(%Scope{user: user}, %Deal{} = deal, attrs) do
    if deal.user_id == user.id and valid_related_records?(user.id, attrs) do
      changeset = Deal.changeset(deal, attrs)

      Ecto.Multi.new()
      |> Ecto.Multi.update(:deal, changeset)
      |> maybe_log_move(user.id, deal, attrs)
      |> Repo.transaction()
      |> handle_transaction_result()
    else
      {:error, :not_found}
    end
  end

  @doc "Moves an account-owned deal to a fixed pipeline column."
  def move_deal(%Scope{user: user}, %Deal{} = deal, pipeline_column_id) do
    if deal.user_id == user.id and get_pipeline_column(pipeline_column_id) do
      attrs = %{pipeline_column_id: pipeline_column_id}

      Ecto.Multi.new()
      |> Ecto.Multi.update(:deal, Deal.changeset(deal, attrs))
      |> maybe_log_move(user.id, deal, attrs)
      |> Repo.transaction()
      |> handle_transaction_result()
    else
      {:error, :not_found}
    end
  end

  @doc "Deletes a deal belonging to the current account."
  def delete_deal(%Scope{user: user}, %Deal{} = deal) do
    if deal.user_id == user.id, do: Repo.delete(deal), else: {:error, :not_found}
  end

  @doc "Formats an integer amount using Indonesian Rupiah grouping."
  def format_idr(amount) when is_integer(amount) do
    grouped =
      amount
      |> Integer.to_string()
      |> String.reverse()
      |> String.graphemes()
      |> Enum.chunk_every(3)
      |> Enum.map(fn chunk -> chunk |> Enum.reverse() |> Enum.join() end)
      |> Enum.reverse()
      |> Enum.join(".")

    "Rp #{grouped}"
  end

  defp fetch_id(attrs, key) do
    case Map.get(attrs, key) || Map.get(attrs, Atom.to_string(key)) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, :missing}
    end
  end

  defp parse_due(attrs) do
    date = Map.get(attrs, "due_date") || Map.get(attrs, :due_date)
    time = Map.get(attrs, "due_time") || Map.get(attrs, :due_time)

    with {:ok, date} <- Date.from_iso8601(to_string(date || "")),
         {:ok, time} <- parse_time(time) do
      date
      |> NaiveDateTime.new!(time)
      |> DateTime.from_naive!("Etc/UTC")
      |> DateTime.add(-@jakarta_offset_seconds)
      |> then(&{:ok, &1})
    else
      _ -> {:error, :invalid_due}
    end
  end

  defp create_next_action_for_user(user, deal, attrs) do
    with {:ok, due} <- parse_due(attrs),
         changeset <-
           NextAction.changeset(%NextAction{user_id: user.id, deal_id: deal.id}, %{
             description: Map.get(attrs, "description") || Map.get(attrs, :description),
             due: due
           }),
         {:ok, :valid} <- ensure_valid(changeset) do
      insert_next_action(user, deal, changeset)
    else
      {:error, changeset} when is_struct(changeset, Ecto.Changeset) -> {:error, changeset}
      {:error, reason} -> {:error, action_changeset(attrs, reason)}
    end
  end

  defp insert_next_action(user, deal, changeset) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:next_action, changeset)
    |> Ecto.Multi.insert(:activity, fn %{next_action: action} ->
      %Activity{user_id: user.id, deal_id: deal.id}
      |> Activity.changeset(%{description: "Follow-up added: #{action.description}."})
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{next_action: action}} -> {:ok, action}
      {:error, _operation, changeset, _changes} -> {:error, changeset}
    end
  end

  defp parse_time(nil), do: {:ok, ~T[23:59:59]}
  defp parse_time(""), do: {:ok, ~T[23:59:59]}

  defp parse_time(value),
    do: Time.from_iso8601(value <> if(byte_size(value) == 5, do: ":00", else: ""))

  defp ensure_valid(%Ecto.Changeset{valid?: true}), do: {:ok, :valid}
  defp ensure_valid(changeset), do: {:error, changeset}

  defp action_changeset(attrs, :invalid_due) do
    NextAction.changeset(%NextAction{}, attrs)
    |> Ecto.Changeset.add_error(:due, "must include a valid date")
  end

  defp valid_related_records?(user_id, attrs) do
    with {:ok, contact_id} <- fetch_id(attrs, :contact_id),
         %Contact{} <- Repo.get_by(Contact, id: contact_id, user_id: user_id),
         {:ok, pipeline_column_id} <- fetch_id(attrs, :pipeline_column_id),
         %PipelineColumn{} <- get_pipeline_column(pipeline_column_id) do
      true
    else
      _ -> false
    end
  end

  defp maybe_log_move(multi, user_id, %Deal{pipeline_column_id: old_id}, attrs) do
    new_id = Map.get(attrs, :pipeline_column_id) || Map.get(attrs, "pipeline_column_id")

    if new_id && new_id != old_id do
      old_column = get_pipeline_column(old_id)
      new_column = get_pipeline_column(new_id)

      Ecto.Multi.run(multi, :activity, fn repo, %{deal: deal} ->
        %Activity{user_id: user_id, deal_id: deal.id}
        |> Activity.changeset(%{
          description: "Moved from #{old_column.name} to #{new_column.name}."
        })
        |> repo.insert()
      end)
    else
      multi
    end
  end

  defp handle_transaction_result({:ok, %{deal: deal}}), do: {:ok, deal}

  defp handle_transaction_result({:error, _operation, changeset, _changes}),
    do: {:error, changeset}

  defp put_contact_if_owned(changeset, %Scope{user: user}, contact_id) do
    if Repo.get_by(Contact, id: contact_id, user_id: user.id),
      do: changeset,
      else: add_error(changeset, :contact_id, "is invalid")
  end
end
