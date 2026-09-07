defmodule Alur.Activities do
  @moduledoc """
  The Activities context.

  All activity log operations are scoped to the authenticated user.
  Activity records are immutable and append-only.
  """

  import Ecto.Query, warn: false
  alias Alur.Accounts.Scope
  alias Alur.Accounts.User
  alias Alur.Activities.Activity
  alias Alur.Deals.Deal
  alias Alur.Deals.PipelineColumn
  alias Alur.Repo

  @doc """
  Lists activities for a deal belonging to the scoped user, newest-first.
  """
  def list_activities_for_deal(%Scope{user: %User{id: user_id}}, deal_or_id) do
    deal_id = extract_deal_id(deal_or_id)

    from(a in Activity,
      where: a.user_id == ^user_id and a.deal_id == ^deal_id,
      order_by: [desc: a.inserted_at, desc: a.id]
    )
    |> Repo.all()
  end

  @doc """
  Logs an activity for a deal.
  Validates that the deal belongs to the scoped user.
  """
  def log_activity(%Scope{user: %User{id: user_id}}, deal_or_id, attrs) do
    deal_id = extract_deal_id(deal_or_id)

    case Repo.get_by(Deal, id: deal_id, user_id: user_id) do
      nil ->
        {:error, :not_found}

      %Deal{} ->
        attrs =
          attrs
          |> Enum.into(%{})
          |> Map.put(:user_id, user_id)
          |> Map.put(:deal_id, deal_id)

        %Activity{}
        |> Activity.changeset(attrs)
        |> Repo.insert()
    end
  end

  @doc """
  Logs a created line when a new deal is created.
  """
  def log_deal_created(%Scope{} = scope, %Deal{} = deal) do
    log_activity(scope, deal.id, %{
      description: "Deal created",
      action_type: "created",
      metadata: %{
        pipeline_column_id: deal.pipeline_column_id
      }
    })
  end

  @doc """
  Logs a move line when a deal changes pipeline column (stage).
  """
  def log_deal_moved(%Scope{} = scope, %Deal{} = deal, old_column, new_column) do
    to_name = column_name(new_column)
    from_name = column_name(old_column)

    log_activity(scope, deal.id, %{
      description: "Moved to #{to_name}",
      action_type: "moved",
      metadata: %{
        from_column_id: column_id(old_column),
        from_column_name: from_name,
        to_column_id: column_id(new_column),
        to_column_name: to_name
      }
    })
  end

  @doc """
  Logs a free-text user note for a deal.
  """
  def log_note(%Scope{} = scope, deal_or_id, note_text) do
    log_activity(scope, deal_or_id, %{
      description: note_text,
      action_type: "note"
    })
  end

  ## Hook points for Milestone 6 (Next actions)

  @doc """
  Hook point for Milestone 6: logs when a next action is added to a deal.
  """
  def log_next_action_added(%Scope{} = scope, deal_or_id, action_description) do
    log_activity(scope, deal_or_id, %{
      description: "Added next action: #{action_description}",
      action_type: "next_action_added"
    })
  end

  @doc """
  Hook point for Milestone 6: logs when a next action is completed.
  """
  def log_next_action_completed(%Scope{} = scope, deal_or_id, action_description) do
    log_activity(scope, deal_or_id, %{
      description: "Completed next action: #{action_description}",
      action_type: "next_action_completed"
    })
  end

  @doc """
  Formats an activity timestamp into human-readable Indonesian time (WIB / UTC+7).
  """
  def format_activity_time(%DateTime{} = dt) do
    # Asia/Jakarta is UTC+7
    local_dt = DateTime.add(dt, 7 * 3600, :second)
    Calendar.strftime(local_dt, "%d %b %Y, %H:%M")
  end

  def format_activity_time(_), do: ""

  defp extract_deal_id(%Deal{id: id}), do: id
  defp extract_deal_id(id) when is_binary(id), do: id
  defp extract_deal_id(_), do: nil

  defp column_name(%PipelineColumn{name: name}), do: name
  defp column_name(name) when is_binary(name), do: name
  defp column_name(_), do: "unknown"

  defp column_id(%PipelineColumn{id: id}), do: id
  defp column_id(id) when is_binary(id), do: id
  defp column_id(_), do: nil
end
