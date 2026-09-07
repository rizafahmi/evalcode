defmodule AlurWeb.DealsLive do
  @moduledoc """
  The signed-in deal pages: the create form anchored to a contact
  (`/contacts/:contact_id/deals/new`), the deal page (`/deals/:id`) and the
  edit form (`/deals/:id/edit`), plus delete.

  A deal is created from a contact and stays anchored to it, so the create form
  only shows the deal's own fields (title, IDR value, pipeline column, notes).
  Every query is scoped to `@current_scope`, the signed-in account: a deal or
  contact that does not belong to the account (or does not exist) is treated
  the same — the visitor is sent back with a notice. The deal page additionally
  shows the deal's activity log (created and moved lines plus manual notes, see
  `Alur.Activities`), and notes are added straight from that page.
  """

  use AlurWeb, :live_view

  import AlurWeb.NextActionComponents

  alias Alur.Activities
  alias Alur.Contacts
  alias Alur.Deals
  alias Alur.Deals.Deal
  alias Alur.NextActions
  alias Alur.NextActions.NextAction

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket = apply_action(socket, socket.assigns.live_action, params)
    {:noreply, socket}
  end

  defp apply_action(socket, :new, %{"contact_id" => contact_id}) do
    case Contacts.get_contact(socket.assigns.current_scope, contact_id) do
      nil ->
        socket
        |> put_flash(:error, "Contact not found.")
        |> push_navigate(to: ~p"/contacts")

      contact ->
        columns = Deals.list_pipeline_columns()
        default_column_id = hd(columns).id
        deal = %Deal{pipeline_column_id: default_column_id}

        socket
        |> assign(page_title: "New deal")
        |> assign(:contact, contact)
        |> assign(:columns, columns)
        |> assign(:deal, deal)
        |> assign(:form, to_form(Deals.change_deal(deal)))
    end
  end

  defp apply_action(socket, action, %{"id" => id}) when action in [:show, :edit] do
    case Deals.get_deal(socket.assigns.current_scope, id) do
      nil ->
        socket
        |> put_flash(:error, "Deal not found.")
        |> push_navigate(to: ~p"/contacts")

      deal ->
        socket
        |> assign(:page_title, page_title(action, deal))
        |> assign(:deal, deal)
        |> maybe_assign_form(action, deal)
        |> maybe_assign_activity_log(action, deal)
        |> maybe_assign_next_actions(action, deal)
    end
  end

  defp page_title(:show, deal), do: deal.title
  defp page_title(:edit, _deal), do: "Edit deal"

  defp maybe_assign_form(socket, :edit, deal) do
    socket
    |> assign(:contact, deal.contact)
    |> assign(:columns, Deals.list_pipeline_columns())
    |> assign(:form, to_form(Deals.change_deal(deal)))
  end

  defp maybe_assign_form(socket, _action, _deal), do: socket

  defp maybe_assign_activity_log(socket, :show, deal) do
    socket
    |> assign(:activities, Activities.list_for_deal(deal))
    |> assign(:note_form, to_form(%{"description" => ""}, as: :note))
  end

  defp maybe_assign_activity_log(socket, _action, _deal), do: socket

  defp maybe_assign_next_actions(socket, :show, deal) do
    socket
    |> refresh_next_actions(deal)
    |> assign(
      :next_action_form,
      to_form(NextActions.change_next_action(%NextAction{}), as: :next_action)
    )
  end

  defp maybe_assign_next_actions(socket, _action, _deal), do: socket

  # Re-reads the deal's follow-ups (open first, then completed) and the count
  # of still-open ones after a follow-up is added or completed.
  defp refresh_next_actions(socket, deal) do
    next_actions = NextActions.list_for_deal(deal)

    socket
    |> assign(:next_actions, next_actions)
    |> assign(:open_action_count, Enum.count(next_actions, &(&1.done == false)))
  end

  @impl true
  def handle_event("validate", %{"deal" => deal_params}, socket) do
    changeset =
      socket.assigns.deal
      |> Deals.change_deal(deal_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"deal" => deal_params}, socket) do
    case socket.assigns.live_action do
      :new -> save_new_deal(socket, deal_params)
      :edit -> save_edited_deal(socket, deal_params)
    end
  end

  @impl true
  def handle_event("delete", _params, socket) do
    deal = socket.assigns.deal
    {:ok, _deal} = Deals.delete_deal(deal)

    {:noreply,
     socket
     |> put_flash(:info, "Deal deleted successfully.")
     |> push_navigate(to: ~p"/contacts/#{deal.contact_id}")}
  end

  @impl true
  def handle_event("add_note", %{"note" => %{"description" => description}}, socket) do
    case String.trim(description || "") do
      "" ->
        # A blank note changes nothing — the log keeps exactly its lines.
        {:noreply, socket}

      text ->
        log_note(socket, text)
    end
  end

  @impl true
  def handle_event("add_next_action", %{"next_action" => params}, socket) do
    deal = socket.assigns.deal

    case NextActions.create_for_deal(deal, normalize_next_action_params(params)) do
      {:ok, _next_action} ->
        {:noreply,
         socket
         |> refresh_next_actions(deal)
         |> refresh_activities(deal)
         |> reset_next_action_form()
         |> put_flash(:info, "Follow-up added.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         assign(
           socket,
           :next_action_form,
           to_form(%{changeset | action: :validate}, as: :next_action)
         )}
    end
  end

  @impl true
  def handle_event("complete_next_action", %{"id" => id}, socket) do
    deal = socket.assigns.deal

    case Enum.find(socket.assigns.next_actions, &(&1.id == id)) do
      nil ->
        {:noreply, socket}

      next_action ->
        case NextActions.complete(next_action) do
          {:ok, _completed} ->
            {:noreply,
             socket
             |> refresh_next_actions(deal)
             |> refresh_activities(deal)
             |> put_flash(:info, "Follow-up completed.")}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Could not complete that follow-up.")}
        end
    end
  end

  defp log_note(socket, text) do
    deal = socket.assigns.deal

    case Activities.log(deal, "Note: " <> text) do
      {:ok, _activity} ->
        {:noreply,
         socket
         |> assign(:activities, Activities.list_for_deal(deal))
         |> assign(:note_form, to_form(%{"description" => ""}, as: :note))
         |> put_flash(:info, "Note added to the activity log.")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "That note is too long. Keep it under 500 characters.")}
    end
  end

  defp normalize_next_action_params(params) do
    %{
      "what" => String.trim(params["what"] || ""),
      "due_date" => blank_to_nil(params["due_date"]),
      "due_time" => blank_to_nil(params["due_time"])
    }
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(value), do: value

  defp refresh_activities(socket, deal) do
    assign(socket, :activities, Activities.list_for_deal(deal))
  end

  defp reset_next_action_form(socket) do
    assign(
      socket,
      :next_action_form,
      to_form(NextActions.change_next_action(%NextAction{}), as: :next_action)
    )
  end

  defp save_new_deal(socket, deal_params) do
    case Deals.create_deal(socket.assigns.current_scope, socket.assigns.contact, deal_params) do
      {:ok, deal} ->
        {:noreply,
         socket
         |> put_flash(:info, "Deal created successfully.")
         |> push_navigate(to: ~p"/deals/#{deal}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(%{changeset | action: :validate}))}
    end
  end

  defp save_edited_deal(socket, deal_params) do
    case Deals.update_deal(socket.assigns.deal, deal_params) do
      {:ok, deal} ->
        {:noreply,
         socket
         |> put_flash(:info, "Deal updated successfully.")
         |> push_navigate(to: ~p"/deals/#{deal}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(%{changeset | action: :validate}))}
    end
  end

  @impl true
  def render(%{live_action: :show} = assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <div>
          <.link
            navigate={~p"/contacts/#{@deal.contact_id}"}
            class="inline-flex items-center gap-1.5 text-sm font-medium font-text tracking-[0.025em] text-fog transition-colors hover:text-ash"
          >
            <.icon name="hero-arrow-left" class="size-4" /> Back to {@deal.contact.name}
          </.link>
        </div>

        <div class="flex flex-wrap items-end justify-between gap-4">
          <div class="min-w-0 space-y-2">
            <div class="flex flex-wrap items-center gap-3">
              <p class="font-mono text-xs uppercase tracking-[0.025em] text-fog">Deal</p>
              <.pipeline_chip name={@deal.pipeline_column.name} />
            </div>
            <h1 class="font-display text-3xl font-semibold tracking-[-0.025em] text-chalk">
              {@deal.title}
            </h1>
            <p class="font-mono text-2xl tracking-[0.025em] text-chalk">
              {Deals.format_idr(@deal.amount)}
            </p>
          </div>

          <div class="flex items-center gap-3">
            <.button navigate={~p"/deals/#{@deal}/edit"} variant="primary">
              <.icon name="hero-pencil-square" class="size-4" /> Edit deal
            </.button>
            <.button
              phx-click="delete"
              data-confirm="Are you sure you want to delete this deal?"
              class="inline-flex items-center justify-center gap-2 rounded-md border border-rose-900/60 bg-transparent px-4 py-2 text-sm font-medium font-text tracking-[0.025em] text-rose-400 shadow-subtle transition-colors duration-150 cursor-pointer hover:border-rose-700/70 hover:text-rose-300"
            >
              <.icon name="hero-trash" class="size-4" /> Delete
            </.button>
          </div>
        </div>

        <div class="overflow-hidden rounded-md border border-basalt bg-graphite shadow-subtle">
          <div class="border-b border-basalt px-5 py-3">
            <span class="font-mono text-xs uppercase tracking-[0.025em] text-fog">Details</span>
          </div>
          <dl class="divide-y divide-basalt px-5">
            <div class="flex flex-col gap-1 py-4 sm:flex-row sm:gap-8">
              <dt class="w-28 shrink-0 font-mono text-xs uppercase tracking-[0.025em] text-fog">
                Value
              </dt>
              <dd class="font-mono text-sm tracking-[0.025em] text-ash">
                {Deals.format_idr(@deal.amount)}
              </dd>
            </div>
            <div class="flex flex-col gap-1 py-4 sm:flex-row sm:gap-8">
              <dt class="w-28 shrink-0 font-mono text-xs uppercase tracking-[0.025em] text-fog">
                Contact
              </dt>
              <dd class="text-sm font-text tracking-[0.025em] text-ash">
                <.link
                  navigate={~p"/contacts/#{@deal.contact}"}
                  class="font-medium text-link-blue hover:underline"
                >
                  {@deal.contact.name}
                </.link>
              </dd>
            </div>
            <div class="flex flex-col gap-1 py-4 sm:flex-row sm:gap-8">
              <dt class="w-28 shrink-0 font-mono text-xs uppercase tracking-[0.025em] text-fog">
                Pipeline column
              </dt>
              <dd>
                <.pipeline_chip name={@deal.pipeline_column.name} />
              </dd>
            </div>
            <div class="flex flex-col gap-1 py-4 sm:flex-row sm:gap-8">
              <dt class="w-28 shrink-0 font-mono text-xs uppercase tracking-[0.025em] text-fog">
                Notes
              </dt>
              <dd class="text-sm font-text tracking-[0.025em] text-ash">
                <%= if @deal.notes not in [nil, ""] do %>
                  <span class="whitespace-pre-wrap">{@deal.notes}</span>
                <% else %>
                  <span class="text-fog">Not set</span>
                <% end %>
              </dd>
            </div>
          </dl>
        </div>

        <div
          id="deal-next-actions"
          class="overflow-hidden rounded-md border border-basalt bg-graphite shadow-subtle"
        >
          <div class="flex items-center justify-between border-b border-basalt px-5 py-3">
            <span class="font-mono text-xs uppercase tracking-[0.025em] text-fog">
              Next actions
            </span>
            <span class="rounded-xs border border-basalt bg-obsidian px-1.5 py-0.5 font-mono text-[10px] tracking-[0.025em] text-fog">
              {@open_action_count} open
            </span>
          </div>

          <%= if @next_actions == [] do %>
            <p class="px-5 py-6 text-sm font-text tracking-[0.025em] text-fog">
              No follow-ups scheduled yet. Overdue items show up here and on the To-dos page.
            </p>
          <% else %>
            <ul class="divide-y divide-basalt">
              <.next_action_row :for={action <- @next_actions} action={action} />
            </ul>
          <% end %>

          <div class="border-t border-basalt px-5 py-4">
            <.form
              for={@next_action_form}
              id="next-action-form"
              phx-submit="add_next_action"
              class="space-y-3"
            >
              <div class="grid gap-3 sm:grid-cols-[1fr_auto] sm:items-end">
                <div class="min-w-0">
                  <.input
                    field={@next_action_form[:what]}
                    type="text"
                    label="What to do"
                    placeholder="e.g. Follow up on the proposal"
                    maxlength="200"
                    autocomplete="off"
                    required
                  />
                </div>
                <div class="grid grid-cols-2 gap-3">
                  <.input
                    field={@next_action_form[:due_date]}
                    type="date"
                    label="Due date"
                    required
                  />
                  <.input
                    field={@next_action_form[:due_time]}
                    type="time"
                    label="Due time (optional)"
                  />
                </div>
              </div>
              <div class="flex items-center justify-end">
                <.button type="submit" phx-disable-with="Adding…">
                  <.icon name="hero-plus" class="size-4" /> Add follow-up
                </.button>
              </div>
            </.form>
          </div>
        </div>

        <div
          id="deal-activity-log"
          class="overflow-hidden rounded-md border border-basalt bg-graphite shadow-subtle"
        >
          <div class="flex items-center justify-between border-b border-basalt px-5 py-3">
            <span class="font-mono text-xs uppercase tracking-[0.025em] text-fog">
              Activity log
            </span>
            <span class="rounded-xs border border-basalt bg-obsidian px-1.5 py-0.5 font-mono text-[10px] tracking-[0.025em] text-fog">
              {length(@activities)}
            </span>
          </div>

          <%= if @activities == [] do %>
            <p class="px-5 py-6 text-sm font-text tracking-[0.025em] text-fog">
              No log entries yet.
            </p>
          <% else %>
            <ul class="divide-y divide-basalt">
              <%= for activity <- @activities do %>
                <li class="activity-row flex flex-wrap items-baseline gap-x-4 gap-y-1 px-5 py-3">
                  <time
                    datetime={DateTime.to_iso8601(activity.inserted_at)}
                    class="shrink-0 font-mono text-xs tracking-[0.025em] text-fog"
                  >
                    {Activities.format_when(activity.inserted_at)}
                  </time>
                  <p class="min-w-0 flex-1 whitespace-pre-wrap break-words text-sm font-text tracking-[0.025em] text-ash">
                    {activity.description}
                  </p>
                </li>
              <% end %>
            </ul>
          <% end %>

          <div class="border-t border-basalt px-5 py-4">
            <.form
              for={@note_form}
              id="note-form"
              phx-submit="add_note"
              class="flex flex-col gap-3 sm:flex-row sm:items-end"
            >
              <div class="min-w-0 flex-1">
                <.input
                  field={@note_form[:description]}
                  type="text"
                  label="Add a note"
                  placeholder="Type a note for the log…"
                  maxlength="500"
                  autocomplete="off"
                />
              </div>
              <.button type="submit">Add note</.button>
            </.form>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def render(%{live_action: action} = assigns) when action in [:new, :edit] do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-2xl space-y-6">
        <div class="flex items-center justify-between gap-4">
          <div class="space-y-1">
            <p class="font-mono text-xs uppercase tracking-[0.025em] text-fog">Deals</p>
            <h1 class="font-display text-3xl font-semibold tracking-[-0.025em] text-chalk">
              {if @live_action == :new, do: "New deal", else: "Edit deal"}
            </h1>
            <p class="text-sm font-text tracking-[0.025em] text-fog">
              Deal for
              <.link
                navigate={~p"/contacts/#{@contact}"}
                class="font-medium text-link-blue hover:underline"
              >
                {@contact.name}
              </.link>
            </p>
          </div>
          <.link
            navigate={
              if @live_action == :edit, do: ~p"/deals/#{@deal}", else: ~p"/contacts/#{@contact}"
            }
            class="inline-flex items-center gap-1.5 text-sm font-medium font-text tracking-[0.025em] text-fog transition-colors hover:text-ash"
          >
            <.icon name="hero-arrow-left" class="size-4" /> Cancel
          </.link>
        </div>

        <div class="rounded-md border border-basalt bg-graphite p-6 shadow-subtle sm:p-8">
          <.form
            for={@form}
            id="deal-form"
            phx-change="validate"
            phx-submit="save"
            class="space-y-5"
          >
            <.input
              field={@form[:title]}
              type="text"
              label="Title"
              placeholder="e.g. Website redesign"
              required
            />

            <div class="grid gap-5 sm:grid-cols-2">
              <.input
                field={@form[:amount]}
                type="number"
                label="Value (IDR)"
                placeholder="e.g. 15000000"
                min="0"
                step="1"
                required
              />
              <.input
                field={@form[:pipeline_column_id]}
                type="select"
                label="Pipeline column"
                options={Enum.map(@columns, &{&1.name, &1.id})}
              />
            </div>

            <.input
              field={@form[:notes]}
              type="textarea"
              label="Notes"
              placeholder="What's the opportunity? Pricing, scope, next steps…"
              rows="4"
            />

            <div class="flex items-center justify-end gap-3 border-t border-basalt pt-5">
              <.link
                navigate={
                  if @live_action == :edit, do: ~p"/deals/#{@deal}", else: ~p"/contacts/#{@contact}"
                }
                class="inline-flex items-center justify-center rounded-md border border-basalt px-4 py-2 text-sm font-medium font-text tracking-[0.025em] text-ash transition-colors duration-150 hover:border-pewter hover:text-chalk"
              >
                Cancel
              </.link>
              <.button type="submit" variant="primary" phx-disable-with="Saving…">
                Save deal
              </.button>
            </div>
          </.form>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp pipeline_chip(assigns) do
    ~H"""
    <span class="inline-flex items-center rounded-xs border border-basalt bg-obsidian px-1.5 py-0.5 font-mono text-xs uppercase tracking-[0.025em] text-silver shadow-subtle">
      {@name}
    </span>
    """
  end
end
