defmodule AlurWeb.ContactLive.Index do
  use AlurWeb, :live_view

  alias Alur.Contacts

  @impl true
  def mount(_params, _session, socket) do
    contacts = Contacts.list_contacts(socket.assigns.current_scope)

    {:ok,
     assign(socket,
       page_title: "Contacts",
       active_tab: :contacts,
       search: "",
       contacts: contacts
     )}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    contacts = Contacts.list_contacts(socket.assigns.current_scope, search)
    {:noreply, assign(socket, search: search, contacts: contacts)}
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    contacts = Contacts.list_contacts(socket.assigns.current_scope)
    {:noreply, assign(socket, search: "", contacts: contacts)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    contact = Contacts.get_contact!(scope, id)
    {:ok, _} = Contacts.delete_contact(scope, contact)

    contacts = Contacts.list_contacts(scope, socket.assigns.search)

    {:noreply,
     socket
     |> put_flash(:info, "Contact deleted successfully.")
     |> assign(contacts: contacts)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active_tab={@active_tab}>
      <div class="space-y-6">
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div>
            <h1 class="text-2xl font-semibold tracking-[-0.025em] text-chalk font-display">
              Contacts
            </h1>
            <p class="mt-1 text-sm text-fog font-text tracking-[0.025em]">
              People and organizations in your CRM
            </p>
          </div>
          <%= if @contacts != [] || @search != "" do %>
            <div>
              <.button variant="primary" navigate={~p"/contacts/new"}>
                <.icon name="hero-plus" class="size-4" />
                <span>New contact</span>
              </.button>
            </div>
          <% end %>
        </div>

        <div class="rounded-md bg-graphite border border-basalt p-3 shadow-subtle">
          <form phx-change="search" phx-submit="search" class="relative">
            <div class="relative">
              <label for="search-input" class="sr-only">Search contacts</label>
              <div class="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3">
                <.icon name="hero-magnifying-glass" class="size-4 text-fog" />
              </div>
              <input
                type="search"
                name="search"
                id="search-input"
                value={@search}
                placeholder="Search contacts by name..."
                aria-label="Search contacts"
                class="block w-full rounded-md border border-basalt bg-obsidian py-2 pl-9 pr-8 text-ash placeholder:text-fog focus:border-moss-border focus:outline-none focus:ring-1 focus:ring-moss-border sm:text-sm font-text tracking-[0.025em] shadow-subtle"
              />
              <%= if @search != "" do %>
                <button
                  type="button"
                  phx-click="clear_search"
                  class="absolute inset-y-0 right-0 flex items-center pr-3 text-fog hover:text-ash cursor-pointer"
                  aria-label="Clear search"
                >
                  <.icon name="hero-x-mark" class="size-4" />
                </button>
              <% end %>
            </div>
          </form>
        </div>

        <%= cond do %>
          <% @contacts == [] && @search != "" -> %>
            <div class="rounded-md bg-graphite border border-basalt p-8 text-center shadow-subtle">
              <.icon name="hero-magnifying-glass" class="mx-auto size-8 text-fog" />
              <h3 class="mt-2 text-base font-semibold text-chalk font-display">
                No contacts found
              </h3>
              <p class="mt-1 text-sm text-silver font-text">
                No contacts match "<span class="text-ash font-medium">{@search}</span>".
              </p>
              <div class="mt-4">
                <.button phx-click="clear_search">
                  Clear search
                </.button>
              </div>
            </div>
          <% @contacts == [] -> %>
            <div class="rounded-md bg-graphite border border-basalt p-8 text-center shadow-subtle">
              <.icon name="hero-user-group" class="mx-auto size-8 text-fog" />
              <h3 class="mt-2 text-base font-semibold text-chalk font-display">
                No contacts yet
              </h3>
              <p class="mt-1 text-sm text-silver font-text max-w-sm mx-auto">
                Keep track of leads, clients, and partners. Add your first contact to get started.
              </p>
              <div class="mt-4">
                <.button variant="primary" navigate={~p"/contacts/new"}>
                  <.icon name="hero-plus" class="size-4" />
                  <span>New contact</span>
                </.button>
              </div>
            </div>
          <% true -> %>
            <div class="rounded-md bg-graphite border border-basalt overflow-hidden shadow-subtle">
              <div class="overflow-x-auto">
                <table class="w-full text-left text-sm text-silver font-text tracking-[0.025em]">
                  <thead class="border-b border-basalt bg-obsidian text-xs uppercase text-fog font-medium tracking-[0.025em]">
                    <tr>
                      <th scope="col" class="py-3 px-4">Name</th>
                      <th scope="col" class="py-3 px-4">Company</th>
                      <th scope="col" class="py-3 px-4">Email</th>
                      <th scope="col" class="py-3 px-4 text-right">
                        <span class="sr-only">Actions</span>
                      </th>
                    </tr>
                  </thead>
                  <tbody id="contacts-table" class="divide-y divide-basalt">
                    <%= for contact <- @contacts do %>
                      <tr
                        id={"contact-#{contact.id}"}
                        class="even:bg-obsidian/30 hover:bg-slate/50 transition-colors"
                      >
                        <td class="py-3 px-4 font-medium text-ash">
                          <.link
                            navigate={~p"/contacts/#{contact}"}
                            class="font-medium text-chalk hover:text-signal-green transition-colors"
                          >
                            {contact.name}
                          </.link>
                        </td>
                        <td class="py-3 px-4 text-silver">
                          {contact.company || "—"}
                        </td>
                        <td class="py-3 px-4 text-silver">
                          {contact.email || "—"}
                        </td>
                        <td class="py-3 px-4 text-right whitespace-nowrap">
                          <div class="flex items-center justify-end gap-2">
                            <.link
                              navigate={~p"/contacts/#{contact}"}
                              class="px-2 py-1 text-xs font-medium font-text tracking-[0.025em] text-fog hover:text-ash rounded-xs hover:bg-obsidian transition-colors"
                            >
                              View
                            </.link>
                            <.link
                              navigate={~p"/contacts/#{contact}/edit"}
                              class="px-2 py-1 text-xs font-medium font-text tracking-[0.025em] text-fog hover:text-ash rounded-xs hover:bg-obsidian transition-colors"
                            >
                              Edit
                            </.link>
                            <button
                              type="button"
                              phx-click="delete"
                              phx-value-id={contact.id}
                              data-confirm={"Are you sure you want to delete #{contact.name}?"}
                              class="px-2 py-1 text-xs font-medium font-text tracking-[0.025em] text-rose-400/80 hover:text-rose-300 rounded-xs hover:bg-rose-950/30 transition-colors cursor-pointer"
                            >
                              Delete
                            </button>
                          </div>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
