defmodule AlurWeb.NextActionComponents do
  @moduledoc """
  Shared markup for one follow-up (next action) row, used by the deal page
  (open and completed follow-ups stay visible there) and by the To-dos page
  (which lists open follow-ups across the account's deals).

  A row shows what needs doing, when it is due (`NextActions.format_due/1`),
  an "Overdue" chip when an open follow-up is past due, an optional link to
  the deal it belongs to, and either a "Mark done" button (open) or a done
  marker (completed). The "Mark done" button pushes a `complete_next_action`
  event that the hosting LiveView handles.
  """

  use AlurWeb, :html

  alias Alur.NextActions

  attr :action, :map, required: true, doc: "the %Alur.NextActions.NextAction{} row"
  attr :show_deal, :boolean, default: false, doc: "link the row's deal name to the deal page"

  def next_action_row(assigns) do
    ~H"""
    <li
      id={"next-action-" <> @action.id}
      class={[
        "next-action-row flex items-start justify-between gap-4 px-5 py-3",
        @action.done && "opacity-80"
      ]}
    >
      <div class="flex min-w-0 items-start gap-3">
        <%= if @action.done do %>
          <span
            class="mt-0.5 inline-flex size-5 shrink-0 items-center justify-center rounded-xs bg-forest-wash text-signal-green"
            aria-label="Completed"
          >
            <.icon name="hero-check" class="size-3.5" />
          </span>
        <% else %>
          <button
            type="button"
            phx-click="complete_next_action"
            phx-value-id={@action.id}
            aria-label={"Mark done: " <> @action.what}
            class="inline-flex shrink-0 items-center gap-1.5 rounded-md border border-basalt bg-transparent px-2.5 py-1 font-mono text-[11px] font-medium uppercase tracking-[0.025em] text-fog shadow-subtle transition-colors duration-150 cursor-pointer hover:border-pewter hover:text-chalk"
          >
            Mark done
          </button>
        <% end %>

        <div class="min-w-0 flex-1">
          <p class={[
            "break-words text-sm font-text tracking-[0.025em] text-ash",
            @action.done && "line-through text-fog"
          ]}>
            {@action.what}
          </p>
          <div class="mt-1 flex flex-wrap items-center gap-x-3 gap-y-1 font-mono text-xs tracking-[0.025em] text-fog">
            <time datetime={Date.to_iso8601(@action.due_date)}>
              {NextActions.format_due(@action)}
            </time>
            <.link
              :if={@show_deal and @action.deal}
              navigate={~p"/deals/#{@action.deal}"}
              class="text-link-blue hover:underline"
            >
              {@action.deal.title}
            </.link>
            <span
              :if={!@action.done and NextActions.overdue?(@action)}
              class="rounded-xs border border-rose-900/60 bg-rose-950/40 px-1.5 py-0.5 text-[10px] uppercase tracking-[0.025em] text-rose-300"
            >
              Overdue
            </span>
          </div>
        </div>
      </div>
    </li>
    """
  end
end
