defmodule AlurWeb.ContactsLive do
  use AlurWeb, :live_view

  alias Alur.Contacts
  alias Alur.Contacts.Contact
  alias Alur.Deals

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, search: "", contacts: [], contact: nil, deals: [], form: nil)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    scope = socket.assigns.current_scope

    case socket.assigns.live_action do
      :index ->
        search = Map.get(params, "search", "")

        {:noreply,
         assign(socket,
           search: search,
           contacts: Contacts.list_contacts(scope, search),
           contact: nil,
           deals: [],
           form: nil
         )}

      :new ->
        {:noreply,
         assign(socket,
           contacts: [],
           contact: nil,
           deals: [],
           form: to_form(Contacts.change_contact(scope))
         )}

      action when action in [:show, :edit] ->
        case Contacts.get_contact(scope, params["id"]) do
          nil ->
            {:noreply,
             socket |> put_flash(:error, "Contact not found.") |> push_navigate(to: ~p"/contacts")}

          contact ->
            {:noreply,
             assign(socket,
               contacts: [],
               contact: contact,
               deals: Deals.list_contact_deals(scope, contact.id),
               form: to_form(Contacts.change_contact(scope, contact))
             )}
        end
    end
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket),
    do: {:noreply, push_patch(socket, to: contacts_path(search))}

  def handle_event("validate", %{"contact" => attrs}, socket) do
    changeset = form_changeset(socket, attrs)
    {:noreply, assign(socket, form: to_form(%{changeset | action: :validate}))}
  end

  def handle_event("save", %{"contact" => attrs}, socket) do
    result =
      case socket.assigns.live_action do
        :new ->
          Contacts.create_contact(socket.assigns.current_scope, attrs)

        :edit ->
          Contacts.update_contact(socket.assigns.current_scope, socket.assigns.contact, attrs)
      end

    save_contact(socket, result)
  end

  def handle_event("delete", _params, socket) do
    case Contacts.delete_contact(socket.assigns.current_scope, socket.assigns.contact) do
      {:ok, _contact} ->
        {:noreply,
         socket |> put_flash(:info, "Contact deleted.") |> push_navigate(to: ~p"/contacts")}

      _ ->
        {:noreply, put_flash(socket, :error, "Contact could not be deleted.")}
    end
  end

  defp save_contact(socket, {:ok, contact}) do
    {:noreply,
     socket
     |> put_flash(:info, "Contact saved.")
     |> push_navigate(to: ~p"/contacts/#{contact.id}")}
  end

  defp save_contact(socket, {:error, %Ecto.Changeset{} = changeset}),
    do: {:noreply, assign(socket, form: to_form(changeset))}

  defp save_contact(socket, {:error, :not_found}) do
    {:noreply,
     socket |> put_flash(:error, "Contact not found.") |> push_navigate(to: ~p"/contacts")}
  end

  defp form_changeset(socket, attrs) do
    case socket.assigns.live_action do
      :new ->
        Contacts.change_contact(socket.assigns.current_scope, attrs)

      :edit ->
        Contacts.change_contact(socket.assigns.current_scope, socket.assigns.contact, attrs)
    end
  end

  defp contacts_path(""), do: ~p"/contacts"
  defp contacts_path(search), do: ~p"/contacts?search=#{search}"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section class="space-y-6">
        <%= case @live_action do %>
          <% :index -> %>
            <.contacts_index contacts={@contacts} search={@search} />
          <% :new -> %>
            <.contact_form
              form={@form}
              title="New contact"
              subtitle="Add someone to your workspace."
              submit_label="Create contact"
            />
          <% :edit -> %>
            <.contact_form
              form={@form}
              title="Edit contact"
              subtitle="Keep this contact's details current."
              submit_label="Save changes"
            />
          <% :show -> %>
            <.contact_detail contact={@contact} deals={@deals} />
        <% end %>
      </section>
    </Layouts.app>
    """
  end

  attr :contacts, :list, required: true
  attr :search, :string, required: true

  defp contacts_index(assigns) do
    ~H"""
    <div class="flex flex-col gap-5 border-b border-basalt pb-5 sm:flex-row sm:items-end sm:justify-between">
      <div>
        <p class="font-mono text-xs uppercase tracking-[0.12em] text-signal-green">
          Workspace / people
        </p>
        <h1 class="mt-2 font-display text-4xl font-semibold tracking-[-0.025em] text-chalk">
          Contacts
        </h1>
        <p class="mt-2 max-w-2xl text-base leading-relaxed tracking-[0.025em] text-silver">
          Keep the people connected to your work in one place.
        </p>
      </div>
      <.button variant="primary" navigate={~p"/contacts/new"}>
        <.icon name="hero-plus" class="size-4" /> Add contact
      </.button>
    </div>
    <form id="contact-search" phx-change="search" class="max-w-xl">
      <.input
        name="search"
        value={@search}
        type="search"
        label="Search by name"
        placeholder="Search contacts..."
        phx-debounce="250"
      />
    </form>
    <div
      :if={@contacts == []}
      class="rounded-md border border-basalt bg-graphite p-8 text-center shadow-subtle"
    >
      <.icon name="hero-users" class="mx-auto size-8 text-lilac-accent" />
      <h2 class="mt-4 font-display text-xl font-semibold tracking-[-0.015em] text-chalk">
        No contacts found
      </h2>
      <p class="mt-2 text-sm leading-relaxed tracking-[0.025em] text-fog">
        Add a contact or change your search to get started.
      </p>
    </div>
    <div :if={@contacts != []} id="contacts" class="grid gap-3 md:grid-cols-2">
      <.link
        :for={contact <- @contacts}
        navigate={~p"/contacts/#{contact.id}"}
        id={"contact-#{contact.id}"}
        class="rounded-md border border-basalt bg-graphite p-5 shadow-subtle transition-colors hover:border-pewter"
      >
        <div class="flex items-start justify-between gap-4">
          <div class="min-w-0">
            <h2 class="truncate font-display text-lg font-semibold tracking-[-0.015em] text-chalk">
              {contact.name}
            </h2>
            <p
              :if={contact.company && contact.company != ""}
              class="mt-1 text-sm tracking-[0.025em] text-silver"
            >
              {contact.company}
            </p>
          </div>
          <.icon name="hero-chevron-right" class="size-5 shrink-0 text-fog" />
        </div>
        <p
          :if={contact.email && contact.email != ""}
          class="mt-4 truncate text-sm tracking-[0.025em] text-fog"
        >
          {contact.email}
        </p>
      </.link>
    </div>
    """
  end

  attr :form, Phoenix.HTML.Form, required: true
  attr :title, :string, required: true
  attr :subtitle, :string, required: true
  attr :submit_label, :string, required: true

  defp contact_form(assigns) do
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
        <p class="mt-2 text-base leading-relaxed tracking-[0.025em] text-silver">{@subtitle}</p>
      </div>
      <.form
        for={@form}
        id="contact-form"
        phx-change="validate"
        phx-submit="save"
        class="mt-6 space-y-2 rounded-md border border-basalt bg-graphite p-6 shadow-subtle"
      >
        <.input field={@form[:name]} label="Name" required placeholder="Ada Lovelace" />
        <div class="grid gap-x-4 sm:grid-cols-2">
          <.input field={@form[:email]} type="email" label="Email" placeholder="ada@example.com" />
          <.input field={@form[:phone]} type="tel" label="Phone" placeholder="+62 812..." />
          <.input field={@form[:company]} label="Company" placeholder="Analytical Engines" />
        </div>
        <.input
          field={@form[:notes]}
          type="textarea"
          label="Notes"
          rows="5"
          placeholder="Useful context about this person..."
        />
        <div class="flex items-center gap-3 pt-3">
          <.button variant="primary">{@submit_label}</.button>
          <.button navigate={~p"/contacts"}>Cancel</.button>
        </div>
      </.form>
    </div>
    """
  end

  attr :contact, Contact, required: true
  attr :deals, :list, required: true

  defp contact_detail(assigns) do
    ~H"""
    <div class="max-w-3xl">
      <div class="flex flex-col gap-4 border-b border-basalt pb-5 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <.link
            navigate={~p"/contacts"}
            class="text-sm tracking-[0.025em] text-link-blue hover:text-chalk"
          >
            ← Back to contacts
          </.link>
          <p class="mt-4 font-mono text-xs uppercase tracking-[0.12em] text-signal-green">
            Contact record
          </p>
          <h1 class="mt-2 font-display text-4xl font-semibold tracking-[-0.025em] text-chalk">
            {@contact.name}
          </h1>
        </div>
        <div class="flex flex-wrap gap-2">
          <.button variant="primary" navigate={~p"/contacts/#{@contact.id}/deals/new"}>
            <.icon name="hero-plus" class="size-4" /> New deal
          </.button>
          <.button navigate={~p"/contacts/#{@contact.id}/edit"}>Edit</.button>
          <.button phx-click="delete" data-confirm="Delete this contact?">Delete</.button>
        </div>
      </div>
      <dl class="mt-6 grid gap-px overflow-hidden rounded-md border border-basalt bg-basalt sm:grid-cols-2">
        <.detail_field label="Email" value={@contact.email} />
        <.detail_field label="Phone" value={@contact.phone} />
        <.detail_field label="Company" value={@contact.company} />
        <.detail_field label="Notes" value={@contact.notes} wide />
      </dl>
      <div class="mt-8 border-t border-basalt pt-6">
        <div class="flex items-end justify-between gap-4">
          <div>
            <p class="font-mono text-xs uppercase tracking-[0.12em] text-signal-green">
              Opportunities
            </p>
            <h2 class="mt-2 font-display text-2xl font-semibold tracking-[-0.025em] text-chalk">
              Deals
            </h2>
          </div>
          <span class="font-mono text-xs text-fog">{length(@deals)} total</span>
        </div>
        <div
          :if={@deals == []}
          class="mt-4 rounded-md border border-basalt bg-graphite p-5 text-sm tracking-[0.025em] text-fog"
        >
          No deals for this contact yet.
        </div>
        <div :if={@deals != []} class="mt-4 grid gap-3">
          <.link
            :for={deal <- @deals}
            navigate={~p"/deals/#{deal.id}"}
            id={"deal-#{deal.id}"}
            class="flex flex-col gap-3 rounded-md border border-basalt bg-graphite p-5 transition-colors hover:border-pewter sm:flex-row sm:items-center sm:justify-between"
          >
            <div class="min-w-0">
              <h3 class="truncate font-display text-lg font-semibold tracking-[-0.015em] text-chalk">
                {deal.title}
              </h3>
              <p class="mt-1 text-sm tracking-[0.025em] text-fog">{deal.pipeline_column.name}</p>
            </div>
            <span class="shrink-0 font-mono text-sm text-ash">{Deals.format_idr(deal.amount)}</span>
          </.link>
        </div>
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :string
  attr :wide, :boolean, default: false

  defp detail_field(assigns) do
    ~H"""
    <div class={["bg-graphite p-5", @wide && "sm:col-span-2"]}>
      <dt class="font-mono text-xs uppercase tracking-[0.12em] text-fog">{@label}</dt>
      <dd class="mt-2 whitespace-pre-wrap text-sm leading-relaxed tracking-[0.025em] text-ash">
        {if @value in [nil, ""], do: "—", else: @value}
      </dd>
    </div>
    """
  end
end
