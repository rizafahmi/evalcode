defmodule AlurWeb.DealLive.Show do
  use AlurWeb, :live_view

  alias Alur.Activities
  alias Alur.Deals
  alias Alur.NextActions

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    scope = socket.assigns.current_scope
    deal = Deals.get_deal!(scope, id)
    columns = Deals.list_pipeline_columns()
    activities = Activities.list_activities_for_deal(scope, deal.id)
    incomplete_actions = NextActions.list_incomplete_actions_for_deal(scope, deal.id)
    completed_actions = NextActions.list_completed_actions_for_deal(scope, deal.id)

    {:ok,
     assign(socket,
       page_title: deal.title,
       active_tab: :pipeline,
       deal: deal,
       columns: columns,
       activities: activities,
       incomplete_actions: incomplete_actions,
       completed_actions: completed_actions,
       note_text: "",
       action_what: "",
       action_due_date: "",
       action_due_time: ""
     )}
  end

  @impl true
  def handle_event("delete", _params, socket) do
    scope = socket.assigns.current_scope
    deal = socket.assigns.deal
    contact_id = deal.contact_id

    {:ok, _} = Deals.delete_deal(scope, deal)

    {:noreply,
     socket
     |> put_flash(:info, "Deal deleted successfully.")
     |> push_navigate(to: ~p"/contacts/#{contact_id}")}
  end

  @impl true
  def handle_event("change_stage", %{"stage_id" => stage_id}, socket) do
    update_stage(socket, stage_id)
  end

  def handle_event("change_stage", %{"deal" => %{"pipeline_column_id" => stage_id}}, socket) do
    update_stage(socket, stage_id)
  end

  @impl true
  def handle_event("add_note", %{"note" => note_text}, socket) do
    trimmed_note = String.trim(note_text)

    if trimmed_note == "" do
      {:noreply, put_flash(socket, :error, "Note cannot be blank.")}
    else
      scope = socket.assigns.current_scope
      deal = socket.assigns.deal

      case Activities.log_note(scope, deal.id, trimmed_note) do
        {:ok, _activity} ->
          activities = Activities.list_activities_for_deal(scope, deal.id)

          {:noreply,
           socket
           |> assign(activities: activities, note_text: "")
           |> put_flash(:info, "Note added to activity log.")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Could not add note.")}
      end
    end
  end

  @impl true
  def handle_event("add_next_action", %{"next_action" => action_params}, socket) do
    scope = socket.assigns.current_scope
    deal = socket.assigns.deal

    case NextActions.create_next_action(scope, deal.id, action_params) do
      {:ok, _action} ->
        incomplete_actions = NextActions.list_incomplete_actions_for_deal(scope, deal.id)
        completed_actions = NextActions.list_completed_actions_for_deal(scope, deal.id)
        activities = Activities.list_activities_for_deal(scope, deal.id)

        {:noreply,
         socket
         |> assign(
           incomplete_actions: incomplete_actions,
           completed_actions: completed_actions,
           activities: activities,
           action_what: "",
           action_due_date: "",
           action_due_time: ""
         )
         |> put_flash(:info, "Follow-up action scheduled.")}

      {:error, changeset} ->
        error_msg =
          case changeset.errors do
            [{field, {msg, _}} | _] -> "#{field} #{msg}"
            _ -> "Could not add follow-up action."
          end

        {:noreply, put_flash(socket, :error, error_msg)}
    end
  end

  @impl true
  def handle_event("complete_action", %{"id" => action_id}, socket) do
    scope = socket.assigns.current_scope
    deal = socket.assigns.deal

    case NextActions.complete_next_action(scope, action_id) do
      {:ok, _action} ->
        incomplete_actions = NextActions.list_incomplete_actions_for_deal(scope, deal.id)
        completed_actions = NextActions.list_completed_actions_for_deal(scope, deal.id)
        activities = Activities.list_activities_for_deal(scope, deal.id)

        {:noreply,
         socket
         |> assign(
           incomplete_actions: incomplete_actions,
           completed_actions: completed_actions,
           activities: activities
         )
         |> put_flash(:info, "Follow-up marked as completed.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not complete follow-up action.")}
    end
  end

  defp update_stage(socket, stage_id) do
    scope = socket.assigns.current_scope
    deal = socket.assigns.deal

    case Deals.change_deal_stage(scope, deal, stage_id) do
      {:ok, updated_deal} ->
        activities = Activities.list_activities_for_deal(scope, updated_deal.id)

        {:noreply,
         socket
         |> assign(
           deal: updated_deal,
           page_title: updated_deal.title,
           activities: activities
         )
         |> put_flash(:info, "Deal stage updated to #{updated_deal.pipeline_column.name}.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not update stage.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active_tab={@active_tab}>
      <div class="max-w-4xl mx-auto space-y-6">
        <div>
          <.link
            navigate={~p"/contacts/#{@deal.contact_id}"}
            class="inline-flex items-center gap-1.5 text-xs font-text tracking-[0.025em] text-fog hover:text-ash transition-colors mb-3"
          >
            <.icon name="hero-arrow-left" class="size-3.5" />
            <span>Back to {@deal.contact.name}</span>
          </.link>
          <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
            <div>
              <div class="flex items-center gap-3">
                <h1 class="text-2xl font-semibold tracking-[-0.025em] text-chalk font-display">
                  {@deal.title}
                </h1>
                <.stage_badge name={@deal.pipeline_column.name} />
              </div>
              <p class="mt-1 text-sm font-text tracking-[0.025em] text-silver">
                Contact:
                <.link
                  navigate={~p"/contacts/#{@deal.contact_id}"}
                  class="text-link-blue hover:underline ml-1"
                >
                  {@deal.contact.name}
                </.link>
                <span :if={@deal.contact.company} class="text-fog">
                  ({@deal.contact.company})
                </span>
              </p>
            </div>
            <div class="flex items-center gap-3">
              <.button navigate={~p"/deals/#{@deal}/edit"}>
                <.icon name="hero-pencil-square" class="size-4" />
                <span>Edit</span>
              </.button>
              <button
                type="button"
                phx-click="delete"
                data-confirm={"Are you sure you want to delete #{@deal.title}?"}
                class="inline-flex items-center justify-center gap-2 rounded-md bg-transparent px-4 py-2 text-sm font-medium font-text tracking-[0.025em] border border-rose-900/50 text-rose-400 hover:border-rose-700 hover:text-rose-300 transition-all shadow-subtle cursor-pointer"
              >
                <.icon name="hero-trash" class="size-4" />
                <span>Delete</span>
              </button>
            </div>
          </div>
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <div class="sm:col-span-1 rounded-md bg-graphite border border-basalt p-6 shadow-subtle">
            <dt class="text-xs uppercase font-mono text-fog tracking-[0.025em]">Deal Value</dt>
            <dd class="mt-2 text-2xl font-mono font-semibold text-signal-green tracking-[0.025em]">
              {format_idr(@deal.amount)}
            </dd>
          </div>
          <div class="sm:col-span-2 rounded-md bg-graphite border border-basalt p-6 shadow-subtle flex flex-col justify-center">
            <dt class="text-xs uppercase font-mono text-fog tracking-[0.025em] mb-2">
              Pipeline Stage
            </dt>
            <dd>
              <div class="grid grid-cols-5 gap-1.5">
                <button
                  :for={col <- @columns}
                  type="button"
                  phx-click="change_stage"
                  phx-value-stage_id={col.id}
                  class={[
                    "flex flex-col items-center justify-center p-2 rounded-md border text-xs font-mono tracking-[0.025em] transition-all cursor-pointer",
                    col.id == @deal.pipeline_column_id &&
                      "bg-fern-ground border-moss-border text-signal-green font-semibold ring-1 ring-moss-border",
                    col.id != @deal.pipeline_column_id &&
                      "bg-obsidian border-basalt text-fog hover:text-ash hover:border-pewter"
                  ]}
                >
                  <span class="truncate w-full text-center">{col.name}</span>
                </button>
              </div>
            </dd>
          </div>
        </div>

        <div class="rounded-md bg-graphite border border-basalt overflow-hidden shadow-subtle">
          <div class="border-b border-basalt bg-obsidian px-6 py-3 flex items-center justify-between">
            <h2 class="text-xs uppercase font-mono text-fog tracking-[0.025em]">Deal Details</h2>
            <form phx-change="change_stage" class="inline-flex items-center gap-2">
              <label
                for="stage-select"
                class="text-xs font-mono text-fog uppercase tracking-[0.025em]"
              >
                Stage:
              </label>
              <select
                id="stage-select"
                name="stage_id"
                class="rounded-md border border-basalt bg-obsidian py-1 px-2.5 text-ash font-mono text-xs focus:border-moss-border focus:ring-1 focus:ring-moss-border"
              >
                <option
                  :for={col <- @columns}
                  value={col.id}
                  selected={col.id == @deal.pipeline_column_id}
                >
                  {col.name}
                </option>
              </select>
            </form>
          </div>
          <div class="p-6">
            <dl class="grid grid-cols-1 sm:grid-cols-2 gap-6">
              <div>
                <dt class="text-xs uppercase font-mono text-fog tracking-[0.025em]">Title</dt>
                <dd class="mt-1 text-sm font-medium text-chalk font-text tracking-[0.025em]">
                  {@deal.title}
                </dd>
              </div>

              <div>
                <dt class="text-xs uppercase font-mono text-fog tracking-[0.025em]">Contact</dt>
                <dd class="mt-1 text-sm text-ash font-text tracking-[0.025em]">
                  <.link
                    navigate={~p"/contacts/#{@deal.contact_id}"}
                    class="text-link-blue hover:underline font-medium"
                  >
                    {@deal.contact.name}
                  </.link>
                </dd>
              </div>

              <div>
                <dt class="text-xs uppercase font-mono text-fog tracking-[0.025em]">Value (IDR)</dt>
                <dd class="mt-1 text-sm font-mono font-medium text-signal-green tracking-[0.025em]">
                  {format_idr(@deal.amount)}
                </dd>
              </div>

              <div>
                <dt class="text-xs uppercase font-mono text-fog tracking-[0.025em]">
                  Current Column
                </dt>
                <dd class="mt-1 text-sm text-ash font-text tracking-[0.025em]">
                  <.stage_badge name={@deal.pipeline_column.name} />
                </dd>
              </div>

              <div class="sm:col-span-2">
                <dt class="text-xs uppercase font-mono text-fog tracking-[0.025em]">Notes</dt>
                <dd class="mt-1 text-sm text-ash font-text tracking-[0.025em] whitespace-pre-wrap rounded-md bg-obsidian border border-basalt p-4">
                  {@deal.notes || "No notes provided."}
                </dd>
              </div>
            </dl>
          </div>
        </div>
        
    <!-- Next Actions (Follow-ups) -->
        <div class="rounded-md bg-graphite border border-basalt overflow-hidden shadow-subtle">
          <div class="border-b border-basalt bg-obsidian px-6 py-3 flex items-center justify-between">
            <div class="flex items-center gap-2">
              <.icon name="hero-calendar-days" class="size-4 text-fog" />
              <h2 class="text-xs uppercase font-mono text-fog tracking-[0.025em]">Next Actions</h2>
            </div>
            <span class="font-mono text-xs text-silver">
              {length(@incomplete_actions)} pending
            </span>
          </div>
          
    <!-- Add Follow-up Form -->
          <div class="p-6 border-b border-basalt bg-graphite">
            <form phx-submit="add_next_action" class="space-y-3">
              <div class="grid grid-cols-1 sm:grid-cols-6 gap-3">
                <div class="sm:col-span-3">
                  <label for="action-what-input" class="sr-only">What to do</label>
                  <input
                    type="text"
                    id="action-what-input"
                    name="next_action[what]"
                    value={@action_what}
                    placeholder="What to do next... (e.g. Send revised proposal)"
                    required
                    class="w-full rounded-md border border-basalt bg-obsidian px-3.5 py-2 text-sm text-ash font-text placeholder:text-fog/60 focus:border-moss-border focus:ring-1 focus:ring-moss-border tracking-[0.025em]"
                  />
                </div>
                <div class="sm:col-span-2">
                  <label for="action-due-date-input" class="sr-only">Due date</label>
                  <input
                    type="date"
                    id="action-due-date-input"
                    name="next_action[due_date]"
                    value={@action_due_date}
                    required
                    class="w-full rounded-md border border-basalt bg-obsidian px-3.5 py-2 text-sm text-ash font-text placeholder:text-fog/60 focus:border-moss-border focus:ring-1 focus:ring-moss-border tracking-[0.025em]"
                  />
                </div>
                <div class="sm:col-span-1">
                  <label for="action-due-time-input" class="sr-only">Time (optional)</label>
                  <input
                    type="time"
                    id="action-due-time-input"
                    name="next_action[due_time]"
                    value={@action_due_time}
                    placeholder="HH:MM"
                    class="w-full rounded-md border border-basalt bg-obsidian px-3 py-2 text-sm text-ash font-text placeholder:text-fog/60 focus:border-moss-border focus:ring-1 focus:ring-moss-border tracking-[0.025em]"
                  />
                </div>
              </div>
              <div class="flex justify-end">
                <button
                  type="submit"
                  class="inline-flex items-center justify-center gap-2 rounded-md bg-transparent px-4 py-2 text-sm font-medium font-text tracking-[0.025em] text-ash border border-basalt hover:border-pewter hover:text-chalk transition-all shadow-subtle cursor-pointer"
                >
                  <.icon name="hero-plus" class="size-3.5" />
                  <span>Add follow-up</span>
                </button>
              </div>
            </form>
          </div>
          
    <!-- Incomplete Follow-ups Stream -->
          <div id="incomplete-actions-list" class="divide-y divide-basalt/60">
            <div
              :for={action <- @incomplete_actions}
              id={"action-#{action.id}"}
              class={[
                "p-4 sm:px-6 flex items-center justify-between gap-4 transition-colors",
                overdue?(action) && "bg-rose-950/10 border-l-2 border-l-rose-500",
                !overdue?(action) && "hover:bg-obsidian/30"
              ]}
            >
              <div class="flex items-start gap-3 min-w-0">
                <button
                  type="button"
                  phx-click="complete_action"
                  phx-value-id={action.id}
                  title="Mark as done"
                  class="mt-0.5 size-5 rounded-xs border border-basalt hover:border-moss-border hover:bg-fern-ground/50 flex items-center justify-center text-transparent hover:text-signal-green transition-all cursor-pointer shrink-0"
                >
                  <.icon name="hero-check" class="size-3.5" />
                </button>
                <div class="min-w-0">
                  <p class="text-sm font-text text-chalk tracking-[0.025em] font-medium break-words">
                    {action.what}
                  </p>
                  <div class="flex items-center gap-2 mt-1">
                    <span class={[
                      "font-mono text-xs tracking-[0.025em]",
                      overdue?(action) && "text-rose-400 font-medium",
                      !overdue?(action) && "text-fog"
                    ]}>
                      <.icon name="hero-clock" class="size-3 inline-block -mt-0.5 mr-1 text-fog" />
                      Due: {format_due(action)}
                    </span>
                    <span
                      :if={overdue?(action)}
                      class="inline-flex items-center gap-1 rounded-xs bg-rose-950/60 border border-rose-800/80 px-1.5 py-0.2 text-[10px] font-mono font-medium text-rose-400 uppercase tracking-wider"
                    >
                      Overdue
                    </span>
                  </div>
                </div>
              </div>

              <div class="shrink-0">
                <button
                  type="button"
                  phx-click="complete_action"
                  phx-value-id={action.id}
                  class="inline-flex items-center gap-1.5 rounded-md bg-transparent px-3 py-1.5 text-xs font-medium font-text tracking-[0.025em] text-ash border border-basalt hover:border-moss-border hover:text-signal-green transition-all shadow-subtle cursor-pointer"
                >
                  <.icon name="hero-check" class="size-3.5" />
                  <span>Mark done</span>
                </button>
              </div>
            </div>

            <div
              :if={Enum.empty?(@incomplete_actions)}
              class="p-6 text-center text-fog font-text text-sm"
            >
              No pending follow-ups. Schedule one above.
            </div>
          </div>
          
    <!-- Completed Follow-ups (remain visible on the deal) -->
          <div :if={!Enum.empty?(@completed_actions)} class="border-t border-basalt bg-obsidian/30">
            <div class="px-6 py-2.5 border-b border-basalt/40 flex items-center justify-between">
              <span class="text-[11px] font-mono uppercase tracking-[0.025em] text-fog">
                Completed ({length(@completed_actions)})
              </span>
            </div>
            <div id="completed-actions-list" class="divide-y divide-basalt/40">
              <div
                :for={action <- @completed_actions}
                id={"action-#{action.id}"}
                class="p-4 sm:px-6 flex items-center justify-between gap-4 opacity-75"
              >
                <div class="flex items-start gap-3 min-w-0">
                  <div class="mt-0.5 size-5 rounded-xs bg-fern-ground border border-moss-border flex items-center justify-center text-signal-green shrink-0">
                    <.icon name="hero-check" class="size-3.5" />
                  </div>
                  <div class="min-w-0">
                    <p class="text-sm font-text text-fog line-through tracking-[0.025em] break-words">
                      {action.what}
                    </p>
                    <p class="text-xs font-mono text-fog/70 mt-0.5">
                      Completed {format_activity_time(action.completed_at || action.updated_at)}
                    </p>
                  </div>
                </div>
                <span class="font-mono text-xs text-signal-green/80 shrink-0">
                  Done
                </span>
              </div>
            </div>
          </div>
        </div>
        
    <!-- Activity Log -->
        <div class="rounded-md bg-graphite border border-basalt overflow-hidden shadow-subtle">
          <div class="border-b border-basalt bg-obsidian px-6 py-3 flex items-center justify-between">
            <div class="flex items-center gap-2">
              <.icon name="hero-clock" class="size-4 text-fog" />
              <h2 class="text-xs uppercase font-mono text-fog tracking-[0.025em]">Activity Log</h2>
            </div>
            <span class="font-mono text-xs text-silver">
              {length(@activities)} {if length(@activities) == 1, do: "event", else: "events"}
            </span>
          </div>
          
    <!-- Add Note Form -->
          <div class="p-6 border-b border-basalt bg-graphite">
            <form phx-submit="add_note" class="space-y-3">
              <div>
                <label for="deal-note-input" class="sr-only">Add a note</label>
                <textarea
                  id="deal-note-input"
                  name="note"
                  rows="2"
                  placeholder="Type a note to log on this deal..."
                  required
                  class="w-full rounded-md border border-basalt bg-obsidian px-3.5 py-2.5 text-sm text-ash font-text placeholder:text-fog/60 focus:border-moss-border focus:ring-1 focus:ring-moss-border tracking-[0.025em] resize-none"
                ><%= @note_text %></textarea>
              </div>
              <div class="flex justify-end">
                <button
                  type="submit"
                  class="inline-flex items-center justify-center gap-2 rounded-md bg-transparent px-4 py-2 text-sm font-medium font-text tracking-[0.025em] text-ash border border-basalt hover:border-pewter hover:text-chalk transition-all shadow-subtle cursor-pointer"
                >
                  <.icon name="hero-pencil" class="size-3.5" />
                  <span>Add note</span>
                </button>
              </div>
            </form>
          </div>
          
    <!-- Activity Entries List (newest-first) -->
          <div id="activity-log-stream" class="divide-y divide-basalt/60">
            <div
              :for={activity <- @activities}
              id={"activity-#{activity.id}"}
              class="p-4 sm:px-6 flex items-start justify-between gap-4 hover:bg-obsidian/30 transition-colors"
            >
              <div class="flex items-start gap-3 min-w-0">
                <div class="mt-0.5 shrink-0">
                  <%= case activity.action_type do %>
                    <% "created" -> %>
                      <div class="size-6 rounded-xs bg-fern-ground border border-moss-border flex items-center justify-center text-signal-green">
                        <.icon name="hero-sparkles" class="size-3.5" />
                      </div>
                    <% "moved" -> %>
                      <div class="size-6 rounded-xs bg-slate border border-iris-border/50 flex items-center justify-center text-lavender-mist">
                        <.icon name="hero-arrow-right" class="size-3.5" />
                      </div>
                    <% "next_action_added" -> %>
                      <div class="size-6 rounded-xs bg-slate border border-iris-border/50 flex items-center justify-center text-lavender-mist">
                        <.icon name="hero-calendar-days" class="size-3.5" />
                      </div>
                    <% "next_action_completed" -> %>
                      <div class="size-6 rounded-xs bg-fern-ground border border-moss-border flex items-center justify-center text-signal-green">
                        <.icon name="hero-check" class="size-3.5" />
                      </div>
                    <% _ -> %>
                      <div class="size-6 rounded-xs bg-obsidian border border-basalt flex items-center justify-center text-silver">
                        <.icon name="hero-chat-bubble-left-ellipsis" class="size-3.5" />
                      </div>
                  <% end %>
                </div>
                <div class="min-w-0">
                  <p class="text-sm font-text text-ash tracking-[0.025em] whitespace-pre-wrap break-words">
                    {activity.description}
                  </p>
                </div>
              </div>

              <div class="shrink-0 text-right">
                <time
                  datetime={DateTime.to_iso8601(activity.inserted_at)}
                  class="font-mono text-xs text-fog tracking-[0.025em]"
                >
                  {format_activity_time(activity.inserted_at)}
                </time>
              </div>
            </div>

            <div
              :if={Enum.empty?(@activities)}
              class="p-8 text-center text-fog font-mono text-xs"
            >
              No activity recorded yet.
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
