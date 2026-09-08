defmodule AlurWeb.DealsLive do
  use AlurWeb, :live_view

  alias Alur.Contacts
  alias Alur.Deals
  alias Alur.Deals.Deal

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       deal: nil,
       contacts: [],
       columns: [],
       form: nil,
       activities: [],
       activity_form: nil,
       next_actions: [],
       next_action_form: nil
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    scope = socket.assigns.current_scope

    case socket.assigns.live_action do
      :new ->
        case Contacts.get_contact(scope, params["contact_id"]) do
          nil ->
            not_found(socket, "Contact not found.")

          contact ->
            {:noreply,
             assign(socket,
               deal: nil,
               contacts: Contacts.list_contacts(scope),
               columns: Deals.list_pipeline_columns(),
               form: to_form(Deals.change_deal(scope, contact.id))
             )}
        end

      action when action in [:show, :edit] ->
        case Deals.get_deal(scope, params["id"]) do
          nil ->
            not_found(socket, "Deal not found.")

          deal ->
            {:noreply,
             assign(socket,
               deal: deal,
               contacts: Contacts.list_contacts(scope),
               columns: Deals.list_pipeline_columns(),
               form: to_form(Deals.change_deal(scope, deal)),
               activities: Deals.list_deal_activities(scope, deal.id),
               activity_form: to_form(Deals.change_activity(scope, deal)),
               next_actions: Deals.list_deal_next_actions(scope, deal.id),
               next_action_form: to_form(Deals.change_next_action(scope, deal))
             )}
        end
    end
  end

  @impl true
  def handle_event("validate", %{"deal" => attrs}, socket) do
    changeset = form_changeset(socket, attrs)
    {:noreply, assign(socket, form: to_form(%{changeset | action: :validate}))}
  end

  def handle_event("save", %{"deal" => attrs}, socket) do
    result =
      case socket.assigns.live_action do
        :new -> Deals.create_deal(socket.assigns.current_scope, attrs)
        :edit -> Deals.update_deal(socket.assigns.current_scope, socket.assigns.deal, attrs)
      end

    save_deal(socket, result)
  end

  def handle_event("delete", _params, socket) do
    case Deals.delete_deal(socket.assigns.current_scope, socket.assigns.deal) do
      {:ok, _deal} ->
        {:noreply,
         socket
         |> put_flash(:info, "Deal deleted.")
         |> push_navigate(to: ~p"/contacts/#{socket.assigns.deal.contact_id}")}

      _ ->
        {:noreply, put_flash(socket, :error, "Deal could not be deleted.")}
    end
  end

  def handle_event("add-activity", %{"activity" => attrs}, socket) do
    case Deals.create_activity(socket.assigns.current_scope, socket.assigns.deal, attrs) do
      {:ok, _activity} ->
        {:noreply,
         assign(socket,
           activities:
             Deals.list_deal_activities(socket.assigns.current_scope, socket.assigns.deal.id),
           activity_form:
             to_form(Deals.change_activity(socket.assigns.current_scope, socket.assigns.deal))
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, activity_form: to_form(changeset))}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Activity could not be added.")}
    end
  end

  def handle_event("validate-next-action", %{"next_action" => attrs}, socket) do
    changeset = Deals.change_next_action(socket.assigns.current_scope, socket.assigns.deal, attrs)
    {:noreply, assign(socket, next_action_form: to_form(%{changeset | action: :validate}))}
  end

  def handle_event("add-next-action", %{"next_action" => attrs}, socket) do
    case Deals.create_next_action(socket.assigns.current_scope, socket.assigns.deal, attrs) do
      {:ok, _action} ->
        {:noreply,
         assign(socket,
           activities:
             Deals.list_deal_activities(socket.assigns.current_scope, socket.assigns.deal.id),
           next_actions:
             Deals.list_deal_next_actions(socket.assigns.current_scope, socket.assigns.deal.id),
           next_action_form:
             to_form(Deals.change_next_action(socket.assigns.current_scope, socket.assigns.deal))
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, next_action_form: to_form(changeset))}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Follow-up could not be added.")}
    end
  end

  def handle_event("complete-next-action", %{"id" => id}, socket) do
    action = Enum.find(socket.assigns.next_actions, &(&1.id == id))

    case action && Deals.complete_next_action(socket.assigns.current_scope, action) do
      {:ok, _action} ->
        {:noreply,
         assign(socket,
           activities:
             Deals.list_deal_activities(socket.assigns.current_scope, socket.assigns.deal.id),
           next_actions:
             Deals.list_deal_next_actions(socket.assigns.current_scope, socket.assigns.deal.id)
         )}

      _ ->
        {:noreply, put_flash(socket, :error, "Follow-up could not be completed.")}
    end
  end

  defp save_deal(socket, {:ok, deal}) do
    {:noreply,
     socket
     |> put_flash(:info, "Deal saved.")
     |> push_navigate(to: ~p"/deals/#{deal.id}")}
  end

  defp save_deal(socket, {:error, %Ecto.Changeset{} = changeset}),
    do: {:noreply, assign(socket, form: to_form(changeset))}

  defp save_deal(socket, {:error, :not_found}),
    do: not_found(socket, "Contact or pipeline column not found.")

  defp not_found(socket, message) do
    {:noreply, socket |> put_flash(:error, message) |> push_navigate(to: ~p"/contacts")}
  end

  defp form_changeset(socket, attrs) do
    case socket.assigns.live_action do
      :new ->
        Deals.change_deal(socket.assigns.current_scope, attrs["contact_id"])

      :edit ->
        socket.assigns.current_scope
        |> Deals.change_deal(socket.assigns.deal)
        |> Ecto.Changeset.cast(attrs, [:title, :amount, :notes, :contact_id, :pipeline_column_id])
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section class="space-y-6">
        <%= case @live_action do %>
          <% :show -> %>
            <.deal_detail
              deal={@deal}
              activities={@activities}
              activity_form={@activity_form}
              next_actions={@next_actions}
              next_action_form={@next_action_form}
            />
          <% :new -> %>
            <.deal_form
              form={@form}
              contacts={@contacts}
              columns={@columns}
              title="New deal"
              submit_label="Create deal"
            />
          <% :edit -> %>
            <.deal_form
              form={@form}
              contacts={@contacts}
              columns={@columns}
              title="Edit deal"
              submit_label="Save changes"
            />
        <% end %>
      </section>
    </Layouts.app>
    """
  end

  attr :deal, Deal, required: true
  attr :activities, :list, required: true
  attr :activity_form, Phoenix.HTML.Form, required: true
  attr :next_actions, :list, required: true
  attr :next_action_form, Phoenix.HTML.Form, required: true

  defp deal_detail(assigns) do
    ~H"""
    <div class="max-w-3xl">
      <div class="flex flex-col gap-4 border-b border-basalt pb-5 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <.link
            navigate={~p"/contacts/#{@deal.contact_id}"}
            class="text-sm tracking-[0.025em] text-link-blue hover:text-chalk"
          >
            ← Back to {@deal.contact.name}
          </.link>
          <p class="mt-4 font-mono text-xs uppercase tracking-[0.12em] text-signal-green">
            Deal record
          </p>
          <h1 class="mt-2 font-display text-4xl font-semibold tracking-[-0.025em] text-chalk">
            {@deal.title}
          </h1>
        </div>
        <div class="flex gap-2">
          <.button navigate={~p"/deals/#{@deal.id}/edit"}>Edit</.button>
          <.button phx-click="delete" data-confirm="Delete this deal?">Delete</.button>
        </div>
      </div>
      <dl class="mt-6 grid gap-px overflow-hidden rounded-md border border-basalt bg-basalt sm:grid-cols-2">
        <.detail_field label="Value" value={Deals.format_idr(@deal.amount)} />
        <.detail_field label="Pipeline column" value={@deal.pipeline_column.name} />
        <.detail_field label="Contact" value={@deal.contact.name} />
        <.detail_field label="Notes" value={@deal.notes} wide />
      </dl>
      <section class="mt-8 rounded-md border border-basalt bg-graphite p-6 shadow-subtle">
        <div class="flex items-start justify-between gap-4 border-b border-basalt pb-4">
          <div>
            <p class="font-mono text-xs uppercase tracking-[0.12em] text-signal-green">
              Follow-up queue
            </p>
            <h2 class="mt-1 font-display text-xl font-semibold tracking-[-0.015em] text-chalk">
              Next actions
            </h2>
          </div>
          <span class="font-mono text-xs tracking-[0.025em] text-fog">
            {Enum.count(@next_actions, &(!&1.done))} open
          </span>
        </div>
        <div :if={@next_actions == []} class="py-5 text-sm tracking-[0.025em] text-fog">
          No follow-ups scheduled.
        </div>
        <div :if={@next_actions != []} class="divide-y divide-basalt">
          <div :for={action <- @next_actions} class="flex items-start gap-3 py-4 last:pb-0">
            <button
              :if={!action.done}
              type="button"
              phx-click="complete-next-action"
              phx-value-id={action.id}
              aria-label={"Mark #{action.description} done"}
              class="mt-0.5 size-5 shrink-0 rounded-xs border border-basalt text-signal-green hover:border-pewter"
            >
              <.icon name="hero-check" class="hidden size-3.5" />
            </button>
            <.icon
              :if={action.done}
              name="hero-check-circle"
              class="mt-0.5 size-5 shrink-0 text-signal-green"
            />
            <div class="min-w-0">
              <p class={[
                "text-sm leading-relaxed tracking-[0.025em]",
                action.done && "text-fog line-through",
                !action.done && "text-ash"
              ]}>
                {action.description}
              </p>
              <p class={[
                "mt-1 font-mono text-xs tracking-[0.025em]",
                Deals.overdue?(action) && "text-lilac-accent",
                !Deals.overdue?(action) && "text-fog"
              ]}>
                {if Deals.overdue?(action), do: "OVERDUE · ", else: ""}{Deals.format_next_action_due(
                  action
                )}
              </p>
            </div>
          </div>
        </div>
        <.form
          for={@next_action_form}
          id="next-action-form"
          phx-change="validate-next-action"
          phx-submit="add-next-action"
          class="mt-6 border-t border-basalt pt-5"
        >
          <div class="grid gap-x-4 sm:grid-cols-2">
            <.input
              field={@next_action_form[:description]}
              label="What to do"
              required
              placeholder="Send the proposal"
            />
            <.input field={@next_action_form[:due_date]} type="date" label="Due date" required />
            <.input field={@next_action_form[:due_time]} type="time" label="Time (optional)" />
          </div>
          <.button variant="primary" class="mt-3">Schedule follow-up</.button>
        </.form>
      </section>
      <div class="mt-8 grid gap-6 lg:grid-cols-[minmax(0,1.3fr)_minmax(16rem,0.7fr)]">
        <section class="rounded-md border border-basalt bg-graphite p-6 shadow-subtle">
          <div class="flex items-center justify-between border-b border-basalt pb-4">
            <div>
              <p class="font-mono text-xs uppercase tracking-[0.12em] text-signal-green">History</p>
              <h2 class="mt-1 font-display text-xl font-semibold tracking-[-0.015em] text-chalk">
                Activity log
              </h2>
            </div>
            <span class="font-mono text-xs tracking-[0.025em] text-fog">
              {@activities |> length()} entries
            </span>
          </div>
          <div :if={@activities == []} class="pt-5 text-sm tracking-[0.025em] text-fog">
            No activity recorded yet.
          </div>
          <ol :if={@activities != []} class="divide-y divide-basalt">
            <li :for={activity <- @activities} class="flex gap-4 py-4 first:pt-5 last:pb-0">
              <span class="mt-1.5 size-2 shrink-0 rounded-xs bg-signal-green" aria-hidden="true">
              </span>
              <div class="min-w-0">
                <p class="text-sm leading-relaxed tracking-[0.025em] text-ash">
                  {activity.description}
                </p>
                <time
                  class="mt-1 block font-mono text-xs tracking-[0.025em] text-fog"
                  datetime={DateTime.to_iso8601(activity.inserted_at)}
                >
                  {Calendar.strftime(activity.inserted_at, "%Y-%m-%d %H:%M UTC")}
                </time>
              </div>
            </li>
          </ol>
        </section>
        <section class="rounded-md border border-basalt bg-graphite p-6 shadow-subtle">
          <p class="font-mono text-xs uppercase tracking-[0.12em] text-signal-green">Manual entry</p>
          <h2 class="mt-1 font-display text-xl font-semibold tracking-[-0.015em] text-chalk">
            Add a note
          </h2>
          <.form
            for={@activity_form}
            id="activity-form"
            phx-submit="add-activity"
            class="mt-5 space-y-3"
          >
            <.input
              field={@activity_form[:description]}
              type="textarea"
              label="Note"
              rows="5"
              placeholder="Call recap, customer context, or a useful reminder..."
            />
            <.button variant="primary">Add note</.button>
          </.form>
        </section>
      </div>
    </div>
    """
  end

  attr :form, Phoenix.HTML.Form, required: true
  attr :contacts, :list, required: true
  attr :columns, :list, required: true
  attr :title, :string, required: true
  attr :submit_label, :string, required: true

  defp deal_form(assigns) do
    ~H"""
    <div class="max-w-3xl">
      <div class="border-b border-basalt pb-5">
        <.link
          navigate={~p"/contacts"}
          class="text-sm tracking-[0.025em] text-link-blue hover:text-chalk"
        >
          ← Back to contacts
        </.link>
        <h1 class="mt-4 font-display text-4xl font-semibold tracking-[-0.025em] text-chalk">
          {@title}
        </h1>
        <p class="mt-2 text-base leading-relaxed tracking-[0.025em] text-silver">
          Track an opportunity and where it sits in your pipeline.
        </p>
      </div>
      <.form
        for={@form}
        id="deal-form"
        phx-change="validate"
        phx-submit="save"
        class="mt-6 space-y-2 rounded-md border border-basalt bg-graphite p-6 shadow-subtle"
      >
        <.input field={@form[:title]} label="Title" required placeholder="Website redesign" />
        <div class="grid gap-x-4 sm:grid-cols-2">
          <.input
            field={@form[:amount]}
            type="number"
            label="Value (IDR)"
            required
            min="0"
            step="1"
            placeholder="15000000"
          />
          <.input
            field={@form[:contact_id]}
            type="select"
            label="Contact"
            options={Enum.map(@contacts, &{&1.name, &1.id})}
            prompt="Choose a contact"
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
          rows="5"
          placeholder="Useful context about this opportunity..."
        />
        <div class="flex items-center gap-3 pt-3">
          <.button variant="primary">{@submit_label}</.button>
          <.button navigate={~p"/contacts"}>Cancel</.button>
        </div>
      </.form>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :string
  attr :wide, :boolean, default: false

  defp detail_field(assigns) do
    ~H"""
    <div class={[
      "bg-graphite p-5",
      @wide && "sm:col-span-2"
    ]}>
      <dt class="font-mono text-xs uppercase tracking-[0.12em] text-fog">{@label}</dt>
      <dd class="mt-2 whitespace-pre-wrap text-sm leading-relaxed tracking-[0.025em] text-ash">
        {if @value in [nil, ""], do: "—", else: @value}
      </dd>
    </div>
    """
  end
end
