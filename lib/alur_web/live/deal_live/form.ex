defmodule AlurWeb.DealLive.Form do
  use AlurWeb, :live_view

  alias Alur.Contacts
  alias Alur.Deals
  alias Alur.Deals.Deal

  @impl true
  def mount(params, _session, socket) do
    scope = socket.assigns.current_scope
    live_action = socket.assigns.live_action
    columns = Deals.list_pipeline_columns()
    column_options = Enum.map(columns, &{&1.name, &1.id})

    case live_action do
      :new ->
        contact_id = params["contact_id"]

        {fixed_contact, contact_options} =
          if contact_id do
            contact = Contacts.get_contact!(scope, contact_id)
            {contact, [{contact.name, contact.id}]}
          else
            contacts = Contacts.list_contacts(scope)
            options = Enum.map(contacts, &{&1.name, &1.id})
            {nil, options}
          end

        default_column = Deals.default_pipeline_column()

        initial_attrs = %{
          "contact_id" => fixed_contact && fixed_contact.id,
          "pipeline_column_id" => default_column.id
        }

        changeset = Deals.change_deal(scope, %Deal{}, initial_attrs)

        cancel_path =
          if fixed_contact do
            ~p"/contacts/#{fixed_contact}"
          else
            ~p"/contacts"
          end

        {:ok,
         assign(socket,
           page_title: "New deal",
           active_tab: :pipeline,
           deal: %Deal{},
           form: to_form(changeset),
           fixed_contact: fixed_contact,
           contact_options: contact_options,
           column_options: column_options,
           cancel_path: cancel_path
         )}

      :edit ->
        deal = Deals.get_deal!(scope, params["id"])
        contacts = Contacts.list_contacts(scope)
        contact_options = Enum.map(contacts, &{&1.name, &1.id})
        changeset = Deals.change_deal(scope, deal)

        {:ok,
         assign(socket,
           page_title: "Edit deal",
           active_tab: :pipeline,
           deal: deal,
           form: to_form(changeset),
           fixed_contact: nil,
           contact_options: contact_options,
           column_options: column_options,
           cancel_path: ~p"/deals/#{deal}"
         )}
    end
  end

  @impl true
  def handle_event("validate", %{"deal" => deal_params}, socket) do
    scope = socket.assigns.current_scope
    deal_params = maybe_inject_fixed_contact(deal_params, socket.assigns.fixed_contact)

    changeset =
      scope
      |> Deals.change_deal(socket.assigns.deal, deal_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"deal" => deal_params}, socket) do
    deal_params = maybe_inject_fixed_contact(deal_params, socket.assigns.fixed_contact)

    save_deal(socket, socket.assigns.live_action, deal_params)
  end

  defp save_deal(socket, :new, deal_params) do
    scope = socket.assigns.current_scope

    case Deals.create_deal(scope, deal_params) do
      {:ok, deal} ->
        {:noreply,
         socket
         |> put_flash(:info, "Deal created successfully.")
         |> push_navigate(to: ~p"/deals/#{deal}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_deal(socket, :edit, deal_params) do
    scope = socket.assigns.current_scope

    case Deals.update_deal(scope, socket.assigns.deal, deal_params) do
      {:ok, deal} ->
        {:noreply,
         socket
         |> put_flash(:info, "Deal updated successfully.")
         |> push_navigate(to: ~p"/deals/#{deal}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp maybe_inject_fixed_contact(params, %Contacts.Contact{id: contact_id}) do
    Map.put(params, "contact_id", contact_id)
  end

  defp maybe_inject_fixed_contact(params, _), do: params

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active_tab={@active_tab}>
      <div class="max-w-2xl mx-auto space-y-6">
        <div>
          <.link
            navigate={@cancel_path}
            class="inline-flex items-center gap-1.5 text-xs font-text tracking-[0.025em] text-fog hover:text-ash transition-colors mb-3"
          >
            <.icon name="hero-arrow-left" class="size-3.5" />
            <span>Cancel</span>
          </.link>
          <h1 class="text-2xl font-semibold tracking-[-0.025em] text-chalk font-display">
            {@page_title}
          </h1>
          <p class="mt-1 text-sm text-silver font-text tracking-[0.025em]">
            <%= if @live_action == :new do %>
              Record a new sales opportunity with value and starting pipeline stage.
            <% else %>
              Update deal information, amount, or stage.
            <% end %>
          </p>
        </div>

        <div class="rounded-md bg-graphite border border-basalt p-6 sm:p-8 shadow-subtle">
          <.form for={@form} id="deal-form" phx-change="validate" phx-submit="save" class="space-y-5">
            <.input
              field={@form[:title]}
              type="text"
              label="Title"
              placeholder="e.g. Enterprise License 2026"
              required
            />

            <.input
              field={@form[:amount]}
              type="number"
              label="Amount (IDR)"
              placeholder="e.g. 15000000"
              min="0"
              step="1"
              required
            />

            <%= if @fixed_contact do %>
              <div>
                <label class="block text-sm font-medium leading-6 text-ash font-text tracking-[0.025em] mb-1">
                  Contact
                </label>
                <div class="flex items-center gap-2 px-3 py-2 rounded-md bg-obsidian border border-basalt text-ash font-text text-sm">
                  <.icon name="hero-user" class="size-4 text-fog" />
                  <span class="font-medium text-chalk">{@fixed_contact.name}</span>
                  <span :if={@fixed_contact.company} class="text-silver">
                    ({@fixed_contact.company})
                  </span>
                </div>
                <input type="hidden" name="deal[contact_id]" value={@fixed_contact.id} />
              </div>
            <% else %>
              <.input
                field={@form[:contact_id]}
                type="select"
                label="Contact"
                options={@contact_options}
                prompt="Select a contact"
                required
              />
            <% end %>

            <.input
              field={@form[:pipeline_column_id]}
              type="select"
              label="Pipeline Stage"
              options={@column_options}
              required
            />

            <.input
              field={@form[:notes]}
              type="textarea"
              label="Notes"
              placeholder="Key requirements, next steps, context..."
              rows={4}
            />

            <div class="flex items-center justify-end gap-3 pt-4 border-t border-basalt">
              <.button navigate={@cancel_path}>
                Cancel
              </.button>
              <.button variant="primary" type="submit">
                Save deal
              </.button>
            </div>
          </.form>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
