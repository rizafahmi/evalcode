defmodule Alur.NextActionsFixtures do
  @moduledoc """
  Test helpers for creating next actions via the `Alur.NextActions` context.
  """

  alias Alur.Accounts.Scope
  alias Alur.DealsFixtures
  alias Alur.NextActions

  def unique_action_what, do: "Next Action #{System.unique_integer([:positive])}"

  def valid_next_action_attributes(%Scope{} = scope, deal_or_id \\ nil, attrs \\ %{}) do
    deal_id =
      case deal_or_id do
        nil ->
          attrs[:deal_id] || attrs["deal_id"] || DealsFixtures.deal_fixture(scope).id

        %{id: id} ->
          id

        id when is_binary(id) ->
          id
      end

    Enum.into(attrs, %{
      what: unique_action_what(),
      due_date: Date.utc_today() |> Date.add(2),
      deal_id: deal_id
    })
  end

  def next_action_fixture(%Scope{} = scope, deal_or_id \\ nil, attrs \\ %{}) do
    attrs = valid_next_action_attributes(scope, deal_or_id, attrs)
    deal_id = attrs[:deal_id] || attrs["deal_id"]
    {:ok, next_action} = NextActions.create_next_action(scope, deal_id, attrs)
    next_action
  end
end
