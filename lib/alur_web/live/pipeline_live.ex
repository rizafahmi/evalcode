defmodule AlurWeb.PipelineLive do
  use AlurWeb, :live_view

  alias Alur.Deals

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign_board(socket)}
  end

  @impl true
  def handle_event(
        "move-deal",
        %{"deal_id" => deal_id, "pipeline_column_id" => column_id},
        socket
      ) do
    scope = socket.assigns.current_scope

    case Enum.find(socket.assigns.deals, &(&1.id == deal_id)) do
      nil ->
        {:noreply, put_flash(socket, :error, "Deal not found.")}

      deal ->
        case Deals.move_deal(scope, deal, column_id) do
          {:ok, _deal} ->
            {:noreply, assign_board(socket)}

          {:error, :not_found} ->
            {:noreply, put_flash(socket, :error, "Pipeline column not found.")}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Deal could not be moved.")}
        end
    end
  end

  defp assign_board(socket) do
    columns = Deals.list_pipeline_columns()
    deals = Deals.list_pipeline_deals(socket.assigns.current_scope)

    assign(socket,
      columns: columns,
      deals: deals,
      deals_by_column:
        Map.new(
          columns,
          &{&1.id, Enum.filter(deals, fn deal -> deal.pipeline_column_id == &1.id end)}
        ),
      totals:
        Map.new(
          columns,
          &{&1.id,
           Enum.reduce(deals, 0, fn deal, total ->
             if deal.pipeline_column_id == &1.id, do: total + deal.amount, else: total
           end)}
        )
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section id="pipeline-board" phx-hook="PipelineBoard" class="space-y-6">
        <div class="flex flex-col gap-4 border-b border-basalt pb-5 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <p class="font-mono text-xs uppercase tracking-[0.12em] text-signal-green">
              Workspace / pipeline
            </p>
            <h1 class="mt-2 font-display text-4xl font-semibold tracking-[-0.025em] text-chalk">
              Pipeline
            </h1>
            <p class="mt-2 max-w-2xl text-base leading-relaxed tracking-[0.025em] text-silver">
              Move opportunities through the five stages of your working pipeline.
            </p>
          </div>
          <span class="rounded-xs border border-moss-border bg-fern-ground px-2 py-1 font-mono text-xs uppercase tracking-[0.12em] text-signal-green">
            {length(@deals)} active records
          </span>
        </div>
        <div class="grid min-w-0 gap-4 overflow-x-auto pb-2 lg:grid-cols-5">
          <article
            :for={column <- @columns}
            id={"pipeline-column-#{column.id}"}
            data-column-id={column.id}
            class="min-w-[235px] rounded-md border border-basalt bg-graphite shadow-subtle"
          >
            <header class="border-b border-basalt bg-obsidian px-4 py-3">
              <div class="flex items-center justify-between gap-3">
                <h2 class="font-display text-base font-semibold tracking-[-0.015em] text-chalk">
                  {column.name}
                </h2>
                <span class="rounded-xs border border-basalt bg-slate px-1.5 py-0.5 font-mono text-xs text-fog">
                  {length(@deals_by_column[column.id])}
                </span>
              </div>
              <p class="mt-2 font-mono text-xs tracking-[0.025em] text-signal-green">
                {Deals.format_idr(@totals[column.id])}
              </p>
            </header>
            <div data-drop-target={column.id} class="min-h-40 space-y-3 p-3">
              <.link
                :for={deal <- @deals_by_column[column.id]}
                navigate={~p"/deals/#{deal.id}"}
                id={"pipeline-deal-#{deal.id}"}
                data-deal-id={deal.id}
                draggable="true"
                class="block rounded-md border border-basalt bg-obsidian p-4 transition-colors hover:border-pewter hover:bg-slate"
              >
                <p class="font-text text-sm font-medium tracking-[0.025em] text-ash">{deal.title}</p>
                <p class="mt-2 text-xs tracking-[0.025em] text-fog">{deal.contact.name}</p>
                <p class="mt-3 font-mono text-xs tracking-[0.025em] text-silver">
                  {Deals.format_idr(deal.amount)}
                </p>
              </.link>
              <p
                :if={@deals_by_column[column.id] == []}
                class="py-5 text-center font-mono text-xs tracking-[0.025em] text-fog"
              >
                Drop deals here
              </p>
            </div>
          </article>
        </div>
      </section>
    </Layouts.app>
    """
  end
end
