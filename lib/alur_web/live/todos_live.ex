defmodule AlurWeb.TodosLive do
  @moduledoc """
  The signed-in to-dos page: one list of every open follow-up across the
  account's deals.

  Rows come from `Alur.NextActions.list_open/1` — incomplete follow-ups of the
  signed-in account only, soonest due first — and each shows what to do, when
  it is due, and which deal it belongs to (linking through to the deal page).
  Overdue rows are called out, and a follow-up can be marked done straight
  from the list, which removes it here and logs the completion on its deal.
  """

  use AlurWeb, :live_view

  import AlurWeb.NextActionComponents

  alias Alur.NextActions

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "To-dos") |> refresh_next_actions()}
  end

  @impl true
  def handle_event("complete_next_action", %{"id" => id}, socket) do
    case Enum.find(socket.assigns.next_actions, &(&1.id == id)) do
      nil ->
        {:noreply, socket}

      next_action ->
        case NextActions.complete(next_action) do
          {:ok, _completed} ->
            {:noreply,
             socket
             |> refresh_next_actions()
             |> put_flash(:info, "Follow-up completed.")}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Could not complete that follow-up.")}
        end
    end
  end

  defp refresh_next_actions(socket) do
    assign(socket, :next_actions, NextActions.list_open(socket.assigns.current_scope))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-8">
        <div class="space-y-1">
          <p class="font-mono text-xs uppercase tracking-[0.025em] text-fog">
            To-dos
          </p>
          <h1 class="font-display text-3xl font-semibold tracking-[-0.025em] text-chalk">
            To-dos
          </h1>
          <p class="text-sm font-text tracking-[0.025em] text-fog">
            Every follow-up that still needs doing, in one place.
          </p>
        </div>

        <%= if @next_actions == [] do %>
          <.empty_state
            icon="hero-calendar"
            title="Nothing due"
            description="Follow-ups you schedule on a deal will show up here, soonest first, so you never lose the next step."
          />
        <% else %>
          <div class="overflow-hidden rounded-md border border-basalt bg-graphite shadow-subtle">
            <div class="flex items-center justify-between border-b border-basalt px-5 py-3">
              <span class="font-mono text-xs uppercase tracking-[0.025em] text-fog">
                Open follow-ups
              </span>
              <span class="rounded-xs border border-basalt bg-obsidian px-1.5 py-0.5 font-mono text-[10px] tracking-[0.025em] text-fog">
                {length(@next_actions)}
              </span>
            </div>

            <ul id="todo-list" class="divide-y divide-basalt">
              <.next_action_row
                :for={action <- @next_actions}
                action={action}
                show_deal
              />
            </ul>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
