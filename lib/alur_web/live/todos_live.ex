defmodule AlurWeb.TodosLive do
  use AlurWeb, :live_view

  alias Alur.Deals

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket, next_actions: Deals.list_open_next_actions(socket.assigns.current_scope))}
  end

  @impl true
  def handle_event("complete-next-action", %{"id" => id}, socket) do
    action = Enum.find(socket.assigns.next_actions, &(&1.id == id))

    case action && Deals.complete_next_action(socket.assigns.current_scope, action) do
      {:ok, _action} ->
        {:noreply,
         assign(socket, next_actions: Deals.list_open_next_actions(socket.assigns.current_scope))}

      _ ->
        {:noreply, put_flash(socket, :error, "Follow-up could not be completed.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section class="space-y-6">
        <div class="border-b border-basalt pb-5">
          <p class="font-mono text-xs uppercase tracking-[0.12em] text-signal-green">
            Workspace / follow-up
          </p>
          <h1 class="mt-2 font-display text-4xl font-semibold tracking-[-0.025em] text-chalk">
            To-dos
          </h1>
          <p class="mt-2 max-w-2xl text-base leading-relaxed tracking-[0.025em] text-silver">
            Every open follow-up across your deals, ordered by due date.
          </p>
        </div>
        <div
          :if={@next_actions == []}
          class="rounded-md border border-basalt bg-graphite p-8 text-center shadow-subtle"
        >
          <.icon name="hero-check-circle" class="mx-auto size-8 text-lilac-accent" />
          <h2 class="mt-4 font-display text-xl font-semibold tracking-[-0.015em] text-chalk">
            All clear
          </h2>
          <p class="mt-2 text-sm leading-relaxed tracking-[0.025em] text-fog">
            No open follow-ups are waiting.
          </p>
        </div>
        <div
          :if={@next_actions != []}
          class="overflow-hidden rounded-md border border-basalt bg-graphite shadow-subtle"
        >
          <div
            :for={action <- @next_actions}
            class="flex items-start gap-4 border-b border-basalt p-5 last:border-b-0"
          >
            <button
              type="button"
              phx-click="complete-next-action"
              phx-value-id={action.id}
              aria-label={"Mark #{action.description} done"}
              class="mt-0.5 size-5 shrink-0 rounded-xs border border-basalt text-signal-green hover:border-pewter"
            >
              <.icon name="hero-check" class="hidden size-3.5" />
            </button>
            <div class="min-w-0 flex-1">
              <p class="text-sm leading-relaxed tracking-[0.025em] text-ash">{action.description}</p>
              <div class="mt-2 flex flex-wrap items-center gap-x-3 gap-y-1 font-mono text-xs tracking-[0.025em]">
                <span class={if Deals.overdue?(action), do: "text-lilac-accent", else: "text-fog"}>
                  {if Deals.overdue?(action), do: "OVERDUE · ", else: ""}{Deals.format_next_action_due(
                    action
                  )}
                </span>
                <span class="text-steel">/</span>
                <.link navigate={~p"/deals/#{action.deal_id}"} class="text-link-blue hover:text-chalk">
                  {action.deal.title}
                </.link>
              </div>
            </div>
          </div>
        </div>
      </section>
    </Layouts.app>
    """
  end
end
