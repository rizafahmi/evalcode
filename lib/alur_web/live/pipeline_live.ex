defmodule AlurWeb.PipelineLive do
  @moduledoc """
  The signed-in home page: the account's Kanban pipeline.

  The board renders the five fixed pipeline columns (Lead → Lost) in order.
  Each deal of the signed-in account appears as a card on its current column,
  showing the deal title, its contact, and its rupiah value; each column header
  carries the sum of its cards' values. A card can be dragged onto another
  column — dropping it moves the deal through `Alur.Deals.move_deal/3`, which
  is also the single choke point later milestones hook the activity log into —
  and clicking a card opens the deal page.

  The drag-and-drop itself is handled by a colocated client hook
  (`.KanbanBoard`) that translates HTML5 drop events into a `move_deal`
  server event. Without JavaScript the board still renders, totals, and opens
  deals; moves are simply not possible, matching the deal-page column select
  that already exists for that case.
  """

  use AlurWeb, :live_view

  alias Alur.Deals

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(page_title: "Pipeline")
      |> assign_board()

    {:ok, socket}
  end

  @impl true
  def handle_event("move_deal", %{"deal_id" => deal_id, "column_id" => column_id}, socket) do
    case Deals.move_deal(socket.assigns.current_scope, deal_id, column_id) do
      {:ok, _deal} -> {:noreply, assign_board(socket)}
      _error -> {:noreply, socket}
    end
  end

  defp assign_board(socket) do
    deals_by_column =
      socket.assigns.current_scope
      |> Deals.list_deals()
      |> Enum.group_by(& &1.pipeline_column_id)

    board =
      Enum.map(Deals.list_pipeline_columns(), fn column ->
        deals = Map.get(deals_by_column, column.id, [])

        %{
          column: column,
          deals: deals,
          count: length(deals),
          total: Enum.reduce(deals, 0, &(&1.amount + &2))
        }
      end)

    socket
    |> assign(:board, board)
    |> assign(:deal_count, Enum.sum(Enum.map(board, & &1.count)))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <div class="space-y-1">
          <p class="font-mono text-xs uppercase tracking-[0.025em] text-fog">
            Pipeline
          </p>
          <h1 class="font-display text-3xl font-semibold tracking-[-0.025em] text-chalk">
            Deal pipeline
          </h1>
          <p class="text-sm font-text tracking-[0.025em] text-fog">
            Drag a card sideways to move it from Lead through to Won or Lost.
          </p>
        </div>

        <div
          :if={@deal_count == 0}
          class="flex flex-wrap items-center justify-between gap-3 rounded-md border border-basalt bg-graphite px-4 py-3 shadow-subtle"
        >
          <div class="flex min-w-0 items-center gap-3">
            <span class="inline-flex size-8 shrink-0 items-center justify-center rounded-md border border-basalt bg-obsidian">
              <.icon name="hero-view-columns" class="size-4 text-fog" />
            </span>
            <p class="text-sm font-text tracking-[0.025em] text-fog">
              No deals yet — create one from a contact's page and it will appear on this board.
            </p>
          </div>
          <.link
            navigate={~p"/contacts"}
            class="inline-flex shrink-0 items-center justify-center gap-1.5 rounded-md border border-basalt px-3 py-1.5 text-sm font-medium font-text tracking-[0.025em] text-ash transition-colors duration-150 hover:border-pewter hover:text-chalk"
          >
            Browse contacts
          </.link>
        </div>

        <div
          id="pipeline-board"
          phx-hook=".KanbanBoard"
          class="flex items-stretch gap-4 overflow-x-auto pb-1"
        >
          <%= for col <- @board do %>
            <section
              id={"pipeline-column-#{col.column.id}"}
              data-column-id={col.column.id}
              class="flex min-w-52 flex-1 flex-col overflow-hidden rounded-md border border-basalt bg-graphite shadow-subtle transition-colors duration-150"
            >
              <header class="space-y-1 border-b border-basalt bg-obsidian/60 px-3 py-2.5">
                <div class="flex items-center justify-between gap-2">
                  <div class="flex min-w-0 items-center gap-2">
                    <span class={["size-1.5 shrink-0 rounded-xs", column_marker(col.column.name)]} />
                    <h2 class="truncate font-mono text-xs font-medium uppercase tracking-[0.025em] text-ash">
                      {col.column.name}
                    </h2>
                  </div>
                  <span class="shrink-0 rounded-xs border border-basalt bg-obsidian px-1.5 py-0.5 font-mono text-[10px] tracking-[0.025em] text-fog">
                    {col.count}
                  </span>
                </div>
                <p class="font-mono text-sm tracking-[0.025em] text-chalk">
                  {Deals.format_idr(col.total)}
                </p>
              </header>

              <div class="flex flex-1 flex-col gap-2 p-2">
                <%= for deal <- col.deals do %>
                  <.link
                    navigate={~p"/deals/#{deal}"}
                    id={"deal-card-" <> deal.id}
                    draggable="true"
                    data-deal-id={deal.id}
                    class="group flex cursor-grab select-none flex-col gap-1 rounded-md border border-basalt bg-obsidian px-3 py-2.5 shadow-subtle transition-colors duration-150 hover:border-pewter active:cursor-grabbing"
                  >
                    <span class="flex items-start justify-between gap-2">
                      <span class="min-w-0 truncate text-sm font-medium font-text tracking-[0.025em] text-ash">
                        {deal.title}
                      </span>
                      <span class="mt-0.5 shrink-0 text-fog opacity-0 transition-opacity duration-150 group-hover:opacity-100">
                        <.icon name="hero-bars-3" class="size-3.5" />
                      </span>
                    </span>
                    <span class="flex items-center justify-between gap-2">
                      <span class="min-w-0 truncate text-xs font-text tracking-[0.025em] text-fog">
                        {deal.contact.name}
                      </span>
                      <span class="shrink-0 font-mono text-xs tracking-[0.025em] text-silver">
                        {Deals.format_idr(deal.amount)}
                      </span>
                    </span>
                  </.link>
                <% end %>

                <%= if col.deals == [] do %>
                  <div class="flex flex-1 items-center justify-center rounded-xs border border-dashed border-basalt px-3 py-6 text-center font-mono text-xs tracking-[0.025em] text-fog">
                    No deals
                  </div>
                <% end %>
              </div>
            </section>
          <% end %>
        </div>

        <p class="font-mono text-xs tracking-[0.025em] text-fog">
          This board shows deals from your account only. New deals start on the column you pick when you create them from a contact.
        </p>
      </div>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".KanbanBoard">
        export default {
          mounted() {
            this.dragging = false
            this.dealId = null
            this.dragCard = null
            this.targetColumn = null

            const board = this.el
            const columnOf = (node) => {
              return node && node.closest ? node.closest("[data-column-id]") : null
            }

            const onDragStart = (e) => {
              const card = e.target.closest && e.target.closest("[data-deal-id]")
              if (!card) return
              this.dragging = true
              this.dealId = card.getAttribute("data-deal-id")
              this.dragCard = card
              e.dataTransfer.effectAllowed = "move"
              e.dataTransfer.setData("text/plain", this.dealId)
              requestAnimationFrame(() => card.classList.add("is-dragging"))
            }

            const onDragEnd = () => {
              this.clearDragState()
            }

            const onDragOver = (e) => {
              if (!this.dragging) return
              e.preventDefault()
              e.dataTransfer.dropEffect = "move"
            }

            const onDragEnter = (e) => {
              if (!this.dragging) return
              e.preventDefault()
              const column = columnOf(e.target)
              if (column && column !== this.targetColumn) {
                this.clearHighlight()
                column.classList.add("kanban-drop-target")
                this.targetColumn = column
              }
            }

            const onDragLeave = (e) => {
              if (!this.dragging) return
              const leaving = columnOf(e.target)
              const entering = columnOf(e.relatedTarget)
              if (leaving && leaving !== entering) {
                leaving.classList.remove("kanban-drop-target")
                if (this.targetColumn === leaving) this.targetColumn = entering
              }
            }

            const onDrop = (e) => {
              if (!this.dragging) return
              e.preventDefault()
              const column = columnOf(e.target)
              if (column && this.dealId) {
                this.pushEvent("move_deal", {
                  deal_id: this.dealId,
                  column_id: column.getAttribute("data-column-id")
                })
              }
              this.clearDragState()
            }

            board.addEventListener("dragstart", onDragStart)
            board.addEventListener("dragend", onDragEnd)
            board.addEventListener("dragover", onDragOver)
            board.addEventListener("dragenter", onDragEnter)
            board.addEventListener("dragleave", onDragLeave)
            board.addEventListener("drop", onDrop)

            this.unmount = () => {
              board.removeEventListener("dragstart", onDragStart)
              board.removeEventListener("dragend", onDragEnd)
              board.removeEventListener("dragover", onDragOver)
              board.removeEventListener("dragenter", onDragEnter)
              board.removeEventListener("dragleave", onDragLeave)
              board.removeEventListener("drop", onDrop)
            }
          },

          destroyed() {
            if (this.unmount) this.unmount()
          },

          clearDragState() {
            if (this.dragCard) this.dragCard.classList.remove("is-dragging")
            this.clearHighlight()
            this.dragging = false
            this.dealId = null
            this.dragCard = null
            this.targetColumn = null
          },

          clearHighlight() {
            const active = this.el.querySelector(".kanban-drop-target")
            if (active) active.classList.remove("kanban-drop-target")
          }
        }
      </script>
    </Layouts.app>
    """
  end

  defp column_marker("Won"), do: "bg-signal-green"
  defp column_marker("Lost"), do: "bg-fog"
  defp column_marker(_name), do: "bg-iron"
end
