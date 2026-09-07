defmodule AlurWeb.TodoLive do
  use AlurWeb, :live_view

  alias Alur.NextActions

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    todos = NextActions.list_incomplete_actions(scope)

    {:ok,
     assign(socket,
       page_title: "To-dos",
       active_tab: :todos,
       todos: todos
     )}
  end

  @impl true
  def handle_event("complete_todo", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    case NextActions.complete_next_action(scope, id) do
      {:ok, _action} ->
        todos = NextActions.list_incomplete_actions(scope)

        {:noreply,
         socket
         |> assign(todos: todos)
         |> put_flash(:info, "Follow-up marked as completed.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not complete follow-up action.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active_tab={@active_tab}>
      <div class="max-w-5xl mx-auto space-y-6">
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div>
            <div class="flex items-center gap-3">
              <h1 class="text-2xl font-semibold tracking-[-0.025em] text-chalk font-display">
                To-dos
              </h1>
              <span class="rounded-xs bg-obsidian border border-basalt px-2 py-0.5 font-mono text-xs text-silver">
                {length(@todos)} {if length(@todos) == 1, do: "action", else: "actions"}
              </span>
            </div>
            <p class="mt-1 text-sm text-fog font-text tracking-[0.025em]">
              Scheduled follow-up actions across active deals, soonest due first
            </p>
          </div>
        </div>

        <%= if Enum.empty?(@todos) do %>
          <div class="rounded-md bg-graphite border border-basalt p-12 shadow-subtle text-center">
            <div class="size-12 rounded-full bg-obsidian border border-basalt flex items-center justify-center mx-auto mb-4 text-fog">
              <.icon name="hero-check-circle" class="size-6 text-signal-green" />
            </div>
            <h3 class="text-lg font-medium text-chalk font-display mb-1">No pending to-dos</h3>
            <p class="text-sm text-silver font-text max-w-md mx-auto">
              All scheduled follow-ups across your deals have been completed.
            </p>
          </div>
        <% else %>
          <div class="rounded-md bg-graphite border border-basalt overflow-hidden shadow-subtle">
            <div class="border-b border-basalt bg-obsidian px-6 py-3 flex items-center justify-between">
              <div class="flex items-center gap-2">
                <.icon name="hero-queue-list" class="size-4 text-fog" />
                <h2 class="text-xs uppercase font-mono text-fog tracking-[0.025em]">Open Actions</h2>
              </div>
              <span class="font-mono text-xs text-fog">
                Soonest due first
              </span>
            </div>

            <div id="todos-list" class="divide-y divide-basalt/60">
              <div
                :for={todo <- @todos}
                id={"todo-#{todo.id}"}
                class={[
                  "p-4 sm:px-6 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 transition-colors",
                  overdue?(todo) && "bg-rose-950/10 border-l-2 border-l-rose-500",
                  !overdue?(todo) && "hover:bg-obsidian/30"
                ]}
              >
                <div class="flex items-start gap-3 min-w-0 flex-1">
                  <button
                    type="button"
                    phx-click="complete_todo"
                    phx-value-id={todo.id}
                    title="Mark as done"
                    class="mt-0.5 size-5 rounded-xs border border-basalt hover:border-moss-border hover:bg-fern-ground/50 flex items-center justify-center text-transparent hover:text-signal-green transition-all cursor-pointer shrink-0"
                  >
                    <.icon name="hero-check" class="size-3.5" />
                  </button>

                  <div class="min-w-0 flex-1">
                    <div class="flex flex-wrap items-center gap-2">
                      <p class="text-sm font-text text-chalk font-medium tracking-[0.025em] break-words">
                        {todo.what}
                      </p>
                      <span
                        :if={overdue?(todo)}
                        class="inline-flex items-center gap-1 rounded-xs bg-rose-950/60 border border-rose-800/80 px-1.5 py-0.2 text-[10px] font-mono font-medium text-rose-400 uppercase tracking-wider"
                      >
                        Overdue
                      </span>
                    </div>

                    <div class="flex flex-wrap items-center gap-y-1 gap-x-4 mt-1.5 text-xs font-text">
                      <div class="flex items-center gap-1.5 text-fog">
                        <.icon name="hero-briefcase" class="size-3.5 text-fog" />
                        <span>Deal:</span>
                        <.link
                          navigate={~p"/deals/#{todo.deal_id}"}
                          class="text-link-blue hover:underline font-medium font-text"
                        >
                          {todo.deal.title}
                        </.link>
                      </div>

                      <div class={[
                        "flex items-center gap-1.5 font-mono",
                        overdue?(todo) && "text-rose-400 font-medium",
                        !overdue?(todo) && "text-fog"
                      ]}>
                        <.icon name="hero-clock" class="size-3.5 text-fog" />
                        <span>Due: {format_due(todo)}</span>
                      </div>
                    </div>
                  </div>
                </div>

                <div class="shrink-0 flex items-center justify-end">
                  <button
                    type="button"
                    phx-click="complete_todo"
                    phx-value-id={todo.id}
                    class="inline-flex items-center gap-1.5 rounded-md bg-transparent px-3 py-1.5 text-xs font-medium font-text tracking-[0.025em] text-ash border border-basalt hover:border-moss-border hover:text-signal-green transition-all shadow-subtle cursor-pointer"
                  >
                    <.icon name="hero-check" class="size-3.5" />
                    <span>Mark done</span>
                  </button>
                </div>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
