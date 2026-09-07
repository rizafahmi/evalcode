defmodule AlurWeb.ContactsLive do
  @moduledoc """
  The signed-in Contacts section.

  Handles the four contact routes — the searchable list (`/contacts`), the
  create form (`/contacts/new`), the contact page (`/contacts/:id`) and the
  edit form (`/contacts/:id/edit`) — plus delete and live search.

  Every query is scoped to `@current_scope`, the signed-in account, so a
  contact that does not belong to the account (or does not exist at all) is
  treated the same: the visitor is sent back to the list with a notice.
  """

  use AlurWeb, :live_view

  alias Alur.Contacts
  alias Alur.Contacts.Contact
  alias Alur.Deals

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket = apply_action(socket, socket.assigns.live_action, params)
    {:noreply, socket}
  end

  defp apply_action(socket, :index, params) do
    search = params["q"] || ""

    socket
    |> assign(page_title: "Contacts")
    |> assign(:search, search)
    |> assign(:contacts, Contacts.list_contacts(socket.assigns.current_scope, search))
  end

  defp apply_action(socket, :new, _params) do
    contact = %Contact{}

    socket
    |> assign(page_title: "New contact")
    |> assign(:contact, contact)
    |> assign(:form, to_form(Contacts.change_contact(contact)))
  end

  defp apply_action(socket, action, %{"id" => id}) when action in [:show, :edit] do
    case Contacts.get_contact(socket.assigns.current_scope, id) do
      nil ->
        socket
        |> put_flash(:error, "Contact not found.")
        |> push_navigate(to: ~p"/contacts")

      contact ->
        socket
        |> assign(:page_title, page_title(action, contact))
        |> assign(:contact, contact)
        |> assign(:deals, Deals.list_contact_deals(socket.assigns.current_scope, contact.id))
        |> maybe_assign_form(action, contact)
    end
  end

  defp page_title(:show, contact), do: contact.name
  defp page_title(:edit, _contact), do: "Edit contact"

  defp maybe_assign_form(socket, :edit, contact) do
    assign(socket, :form, to_form(Contacts.change_contact(contact)))
  end

  defp maybe_assign_form(socket, _action, _contact), do: socket

  @impl true
  def handle_event("search", params, socket) do
    q = params["q"] || ""

    socket =
      if q == "" do
        push_patch(socket, to: ~p"/contacts")
      else
        push_patch(socket, to: ~p"/contacts?#{%{q: q}}")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", %{"contact" => contact_params}, socket) do
    changeset =
      socket.assigns.contact
      |> Contacts.change_contact(contact_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"contact" => contact_params}, socket) do
    case socket.assigns.live_action do
      :new -> save_new_contact(socket, contact_params)
      :edit -> save_edited_contact(socket, contact_params)
    end
  end

  @impl true
  def handle_event("delete", _params, socket) do
    {:ok, _contact} = Contacts.delete_contact(socket.assigns.contact)

    {:noreply,
     socket
     |> put_flash(:info, "Contact deleted successfully.")
     |> push_navigate(to: ~p"/contacts")}
  end

  defp save_new_contact(socket, contact_params) do
    case Contacts.create_contact(socket.assigns.current_scope, contact_params) do
      {:ok, contact} ->
        {:noreply,
         socket
         |> put_flash(:info, "Contact created successfully.")
         |> push_navigate(to: ~p"/contacts/#{contact}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(%{changeset | action: :validate}))}
    end
  end

  defp save_edited_contact(socket, contact_params) do
    case Contacts.update_contact(socket.assigns.contact, contact_params) do
      {:ok, contact} ->
        {:noreply,
         socket
         |> put_flash(:info, "Contact updated successfully.")
         |> push_navigate(to: ~p"/contacts/#{contact}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(%{changeset | action: :validate}))}
    end
  end

  @impl true
  def render(%{live_action: :index} = assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-8">
        <div class="flex flex-wrap items-end justify-between gap-4">
          <div class="space-y-1">
            <p class="font-mono text-xs uppercase tracking-[0.025em] text-fog">
              Contacts
            </p>
            <h1 class="font-display text-3xl font-semibold tracking-[-0.025em] text-chalk">
              Contacts
            </h1>
            <p class="text-sm font-text tracking-[0.025em] text-fog">
              The people behind every deal — searchable and yours alone.
            </p>
          </div>

          <.button
            :if={@contacts != [] || @search != ""}
            navigate={~p"/contacts/new"}
            variant="primary"
          >
            New contact
          </.button>
        </div>

        <form id="contacts-search" phx-change="search" phx-submit="search" role="search">
          <label for="contacts-search-input" class="sr-only">
            Search contacts by name
          </label>
          <div class="relative max-w-md">
            <.icon
              name="hero-magnifying-glass"
              class="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-fog"
            />
            <input
              id="contacts-search-input"
              type="search"
              name="q"
              value={@search}
              placeholder="Search by name…"
              phx-debounce="300"
              autocomplete="off"
              class="w-full rounded-md border border-basalt bg-obsidian py-2 pr-3 pl-9 text-sm font-text tracking-[0.025em] text-ash shadow-subtle placeholder:text-fog focus:border-moss-border focus:outline-none focus:ring-1 focus:ring-moss-border"
            />
          </div>
        </form>

        <.empty_state
          :if={@contacts == [] && @search == ""}
          icon="hero-users"
          title="No contacts yet"
          description="Add the people you work with — their name and details — and you'll find them here by name."
        >
          <.button navigate={~p"/contacts/new"} variant="primary">
            New contact
          </.button>
        </.empty_state>

        <.empty_state
          :if={@contacts == [] && @search != ""}
          icon="hero-magnifying-glass"
          title="No contacts found"
          description={"No contacts match “#{@search}”. Try a different name, or clear the search."}
        >
          <.button phx-click="search" phx-value-q="">
            Clear search
          </.button>
        </.empty_state>

        <div
          :if={@contacts != []}
          class="overflow-hidden rounded-md border border-basalt bg-graphite shadow-subtle"
        >
          <div class="flex items-center justify-between border-b border-basalt px-4 py-2.5">
            <span class="font-mono text-xs uppercase tracking-[0.025em] text-fog">
              {length(@contacts)} {if length(@contacts) == 1, do: "contact", else: "contacts"}
            </span>
            <span class="inline-block size-2 rounded-xs bg-signal-green" />
          </div>
          <div class="overflow-x-auto">
            <table class="w-full text-left text-sm font-text tracking-[0.025em]">
              <thead>
                <tr class="border-b border-basalt text-xs uppercase text-fog">
                  <th class="px-4 py-3 font-medium">Name</th>
                  <th class="px-4 py-3 font-medium">Company</th>
                  <th class="px-4 py-3 font-medium">Email</th>
                  <th class="px-4 py-3"><span class="sr-only">Open</span></th>
                </tr>
              </thead>
              <tbody class="divide-y divide-basalt" id="contacts">
                <tr
                  :for={contact <- @contacts}
                  id={"contact-#{contact.id}"}
                  class="group transition-colors hover:bg-obsidian/60"
                >
                  <td class="px-4 py-3">
                    <.link
                      navigate={~p"/contacts/#{contact}"}
                      class="font-medium text-chalk transition-colors group-hover:text-signal-green"
                    >
                      {contact.name}
                    </.link>
                  </td>
                  <td class="px-4 py-3 text-silver">{present_or_dash(contact.company)}</td>
                  <td class="px-4 py-3 text-silver">{present_or_dash(contact.email)}</td>
                  <td class="w-0 px-4 py-3 text-right whitespace-nowrap">
                    <.link
                      navigate={~p"/contacts/#{contact}"}
                      aria-label={"Open #{contact.name}"}
                      class="inline-flex text-fog transition-colors hover:text-chalk"
                    >
                      <.icon name="hero-arrow-right" class="size-4" />
                    </.link>
                  </td>
                </tr>
              </tbody>
            </table>
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
            <p class="font-mono text-xs uppercase tracking-[0.025em] text-fog">
              Contacts
            </p>
            <h1 class="font-display text-3xl font-semibold tracking-[-0.025em] text-chalk">
              {if @live_action == :new, do: "New contact", else: "Edit contact"}
            </h1>
          </div>
          <.link
            navigate={if @live_action == :edit, do: ~p"/contacts/#{@contact}", else: ~p"/contacts"}
            class="inline-flex items-center gap-1.5 text-sm font-medium font-text tracking-[0.025em] text-fog transition-colors hover:text-ash"
          >
            <.icon name="hero-arrow-left" class="size-4" /> All contacts
          </.link>
        </div>

        <div class="rounded-md border border-basalt bg-graphite p-6 shadow-subtle sm:p-8">
          <.form
            for={@form}
            id="contact-form"
            phx-change="validate"
            phx-submit="save"
            class="space-y-5"
          >
            <div class="grid gap-5 sm:grid-cols-2">
              <div class="sm:col-span-2">
                <.input
                  field={@form[:name]}
                  type="text"
                  label="Name"
                  placeholder="e.g. Sari Wijaya"
                  required
                />
              </div>
              <.input
                field={@form[:email]}
                type="email"
                label="Email"
                placeholder="sari@example.com"
                autocomplete="off"
              />
              <.input
                field={@form[:phone]}
                type="tel"
                label="Phone"
                placeholder="+62 812 3456 7890"
                autocomplete="off"
              />
              <.input
                field={@form[:company]}
                type="text"
                label="Company"
                placeholder="Acme"
                autocomplete="organization"
              />
              <div class="sm:col-span-2">
                <.input
                  field={@form[:notes]}
                  type="textarea"
                  label="Notes"
                  placeholder="Context about this contact — where you met, what they care about…"
                  rows="4"
                />
              </div>
            </div>

            <div class="flex items-center justify-end gap-3 border-t border-basalt pt-5">
              <.link
                navigate={
                  if @live_action == :edit, do: ~p"/contacts/#{@contact}", else: ~p"/contacts"
                }
                class="inline-flex items-center justify-center rounded-md border border-basalt px-4 py-2 text-sm font-medium font-text tracking-[0.025em] text-ash transition-colors duration-150 hover:border-pewter hover:text-chalk"
              >
                Cancel
              </.link>
              <.button type="submit" variant="primary" phx-disable-with="Saving…">
                Save contact
              </.button>
            </div>
          </.form>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def render(%{live_action: :show} = assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <div>
          <.link
            navigate={~p"/contacts"}
            class="inline-flex items-center gap-1.5 text-sm font-medium font-text tracking-[0.025em] text-fog transition-colors hover:text-ash"
          >
            <.icon name="hero-arrow-left" class="size-4" /> All contacts
          </.link>
        </div>

        <div class="flex flex-wrap items-end justify-between gap-4">
          <div class="space-y-1">
            <p class="font-mono text-xs uppercase tracking-[0.025em] text-fog">
              Contact
            </p>
            <h1 class="font-display text-3xl font-semibold tracking-[-0.025em] text-chalk">
              {@contact.name}
            </h1>
            <p
              :if={@contact.company not in [nil, ""]}
              class="text-sm font-text tracking-[0.025em] text-fog"
            >
              {@contact.company}
            </p>
          </div>

          <div class="flex items-center gap-3">
            <.button navigate={~p"/contacts/#{@contact}/edit"} variant="primary">
              <.icon name="hero-pencil-square" class="size-4" /> Edit contact
            </.button>
            <.button
              phx-click="delete"
              data-confirm="Are you sure you want to delete this contact?"
              class="inline-flex items-center justify-center gap-2 rounded-md border border-rose-900/60 bg-transparent px-4 py-2 text-sm font-medium font-text tracking-[0.025em] text-rose-400 shadow-subtle transition-colors duration-150 cursor-pointer hover:border-rose-700/70 hover:text-rose-300"
            >
              <.icon name="hero-trash" class="size-4" /> Delete
            </.button>
          </div>
        </div>

        <div class="overflow-hidden rounded-md border border-basalt bg-graphite shadow-subtle">
          <div class="border-b border-basalt px-5 py-3">
            <span class="font-mono text-xs uppercase tracking-[0.025em] text-fog">
              Details
            </span>
          </div>
          <dl class="divide-y divide-basalt px-5">
            <div class="flex flex-col gap-1 py-4 sm:flex-row sm:gap-8">
              <dt class="w-28 shrink-0 font-mono text-xs uppercase tracking-[0.025em] text-fog">
                Name
              </dt>
              <dd class="text-sm font-text tracking-[0.025em] text-ash">{@contact.name}</dd>
            </div>
            <div class="flex flex-col gap-1 py-4 sm:flex-row sm:gap-8">
              <dt class="w-28 shrink-0 font-mono text-xs uppercase tracking-[0.025em] text-fog">
                Email
              </dt>
              <dd class="text-sm font-text tracking-[0.025em] text-ash">
                <%= if @contact.email not in [nil, ""] do %>
                  <.link
                    href={"mailto:#{@contact.email}"}
                    class="font-medium text-link-blue hover:underline"
                  >
                    {@contact.email}
                  </.link>
                <% else %>
                  <span class="text-fog">Not set</span>
                <% end %>
              </dd>
            </div>
            <div class="flex flex-col gap-1 py-4 sm:flex-row sm:gap-8">
              <dt class="w-28 shrink-0 font-mono text-xs uppercase tracking-[0.025em] text-fog">
                Phone
              </dt>
              <dd class="text-sm font-text tracking-[0.025em] text-ash">
                <%= if @contact.phone not in [nil, ""] do %>
                  <.link
                    href={"tel:#{@contact.phone}"}
                    class="font-medium text-link-blue hover:underline"
                  >
                    {@contact.phone}
                  </.link>
                <% else %>
                  <span class="text-fog">Not set</span>
                <% end %>
              </dd>
            </div>
            <div class="flex flex-col gap-1 py-4 sm:flex-row sm:gap-8">
              <dt class="w-28 shrink-0 font-mono text-xs uppercase tracking-[0.025em] text-fog">
                Company
              </dt>
              <dd class="text-sm font-text tracking-[0.025em] text-ash">
                {present_or_dash(@contact.company)}
              </dd>
            </div>
            <div class="flex flex-col gap-1 py-4 sm:flex-row sm:gap-8">
              <dt class="w-28 shrink-0 font-mono text-xs uppercase tracking-[0.025em] text-fog">
                Notes
              </dt>
              <dd class="text-sm font-text tracking-[0.025em] text-ash">
                <%= if @contact.notes not in [nil, ""] do %>
                  <span class="whitespace-pre-wrap">{@contact.notes}</span>
                <% else %>
                  <span class="text-fog">Not set</span>
                <% end %>
              </dd>
            </div>
          </dl>
        </div>

        <div class="overflow-hidden rounded-md border border-basalt bg-graphite shadow-subtle">
          <div class="flex items-center justify-between gap-3 border-b border-basalt px-5 py-3">
            <div class="flex items-center gap-3">
              <span class="font-mono text-xs uppercase tracking-[0.025em] text-fog">
                Deals · {length(@deals)}
              </span>
              <span
                :if={@deals != []}
                class="inline-block size-2 rounded-xs bg-signal-green"
                aria-hidden="true"
              />
            </div>
            <.link
              navigate={~p"/contacts/#{@contact}/deals/new"}
              class="inline-flex items-center gap-1.5 rounded-md border border-basalt px-3 py-1.5 text-sm font-medium font-text tracking-[0.025em] text-ash transition-colors duration-150 hover:border-pewter hover:text-chalk"
            >
              <.icon name="hero-plus" class="size-4" /> New deal
            </.link>
          </div>

          <div :if={@deals == []} class="px-6 py-10 text-center">
            <.icon name="hero-banknotes" class="mx-auto mb-3 size-6 text-fog" />
            <p class="text-sm font-text tracking-[0.025em] text-fog">
              No deals for this contact yet. Start one to track an opportunity.
            </p>
          </div>

          <div :if={@deals != []} class="overflow-x-auto">
            <table class="w-full text-left text-sm font-text tracking-[0.025em]">
              <thead>
                <tr class="border-b border-basalt text-xs uppercase text-fog">
                  <th class="px-5 py-3 font-medium">Deal</th>
                  <th class="px-5 py-3 font-medium">Value</th>
                  <th class="px-5 py-3 font-medium">Pipeline column</th>
                  <th class="px-5 py-3"><span class="sr-only">Open</span></th>
                </tr>
              </thead>
              <tbody class="divide-y divide-basalt" id="contact-deals">
                <tr
                  :for={deal <- @deals}
                  id={"deal-#{deal.id}"}
                  class="group transition-colors hover:bg-obsidian/60"
                >
                  <td class="px-5 py-3">
                    <.link
                      navigate={~p"/deals/#{deal}"}
                      class="font-medium text-chalk transition-colors group-hover:text-signal-green"
                    >
                      {deal.title}
                    </.link>
                  </td>
                  <td class="px-5 py-3 font-mono text-silver">
                    {Deals.format_idr(deal.amount)}
                  </td>
                  <td class="px-5 py-3">
                    <.pipeline_chip name={deal.pipeline_column.name} />
                  </td>
                  <td class="w-0 px-5 py-3 text-right whitespace-nowrap">
                    <.link
                      navigate={~p"/deals/#{deal}"}
                      aria-label={"Open #{deal.title}"}
                      class="inline-flex text-fog transition-colors hover:text-chalk"
                    >
                      <.icon name="hero-arrow-right" class="size-4" />
                    </.link>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
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

  defp present_or_dash(value) when value in [nil, ""], do: "—"
  defp present_or_dash(value), do: value
end
