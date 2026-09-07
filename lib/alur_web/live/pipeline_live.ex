defmodule AlurWeb.PipelineLive do
  use AlurWeb, :live_view

  alias Alur.Deals

  @impl true
  def mount(_params, _session, socket) do
    {:ok, load_board(socket)}
  end

  @impl true
  def handle_event("move_deal", %{"deal_id" => deal_id, "column_id" => column_id}, socket) do
    scope = socket.assigns.current_scope

    case Deals.move_deal(scope, deal_id, column_id) do
      {:ok, _deal} ->
        {:noreply, load_board(socket)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Unable to move deal.")}
    end
  end

  defp load_board(socket) do
    scope = socket.assigns[:current_scope]
    columns = if scope, do: Deals.get_pipeline_board(scope), else: []

    socket
    |> assign(
      page_title: "Pipeline",
      active_tab: :pipeline,
      board_columns: columns
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active_tab={@active_tab}>
      <div class="space-y-6">
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div>
            <h1 class="text-2xl sm:text-3xl font-semibold tracking-[-0.025em] text-chalk font-display">
              Pipeline
            </h1>
            <p class="mt-1 text-sm text-fog font-text tracking-[0.025em]">
              Deal flow and stage tracking across your sales pipeline
            </p>
          </div>

          <div>
            <.link
              navigate={~p"/deals/new"}
              class="inline-flex items-center justify-center gap-2 rounded-md bg-signal-green px-4 py-2 text-sm font-medium font-text tracking-[0.025em] text-carbon border border-led-green hover:brightness-105 active:brightness-95 transition-all shadow-subtle"
            >
              <.icon name="hero-plus" class="size-4 shrink-0 stroke-[2.5]" />
              <span>New deal</span>
            </.link>
          </div>
        </div>

        <div
          id="kanban-board"
          phx-hook="KanbanBoard"
          class="grid grid-cols-1 md:grid-cols-5 gap-4 items-start"
        >
          <div
            :for={col_data <- @board_columns}
            id={"column-#{col_data.column.id}"}
            data-column-id={col_data.column.id}
            data-column-name={col_data.column.name}
            class="kanban-column rounded-md bg-graphite border border-basalt p-3.5 flex flex-col min-h-[520px] transition-colors shadow-subtle"
          >
            <div class="flex items-center justify-between pb-3 border-b border-basalt mb-3">
              <div class="flex items-center gap-2">
                <.stage_badge name={col_data.column.name} />
                <span
                  class="text-xs font-mono text-fog font-medium"
                  data-role="column-count"
                  id={"column-count-#{col_data.column.id}"}
                >
                  {col_data.count}
                </span>
              </div>
              <div class="text-right">
                <span
                  class="font-mono text-xs font-semibold text-silver"
                  data-role="column-total"
                  id={"column-total-#{col_data.column.id}"}
                >
                  {format_idr(col_data.total_amount)}
                </span>
              </div>
            </div>

            <div
              id={"dropzone-#{col_data.column.id}"}
              class="kanban-drop-zone flex-1 flex flex-col gap-2.5 min-h-[200px]"
            >
              <.link
                :for={deal <- col_data.deals}
                navigate={~p"/deals/#{deal}"}
                id={"deal-card-#{deal.id}"}
                data-deal-id={deal.id}
                draggable="true"
                class="deal-card block rounded-md bg-obsidian border border-basalt p-3.5 hover:border-pewter transition-all shadow-subtle group cursor-grab active:cursor-grabbing"
              >
                <div class="flex flex-col gap-2">
                  <h3 class="font-display font-medium text-chalk text-sm tracking-[-0.015em] group-hover:text-ash line-clamp-2">
                    {deal.title}
                  </h3>

                  <div class="flex items-center gap-1.5 text-xs text-fog font-text tracking-[0.025em]">
                    <.icon name="hero-user" class="size-3.5 shrink-0 text-fog/60" />
                    <span class="truncate">{deal.contact.name}</span>
                  </div>

                  <div class="mt-1 pt-2 border-t border-basalt/60 flex items-center justify-between">
                    <span class="font-mono text-xs font-semibold text-signal-green">
                      {format_idr(deal.amount)}
                    </span>
                  </div>
                </div>
              </.link>

              <div
                :if={Enum.empty?(col_data.deals)}
                class="empty-column-placeholder flex-1 min-h-[140px] rounded-md border border-dashed border-basalt/50 flex flex-col items-center justify-center text-xs font-mono text-fog/50 p-4 text-center select-none"
              >
                <span>Drop deals here</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
