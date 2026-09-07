defmodule AlurWeb.ContactLive.Show do
  use AlurWeb, :live_view

  alias Alur.Contacts
  alias Alur.Deals

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    scope = socket.assigns.current_scope
    contact = Contacts.get_contact!(scope, id)
    deals = Deals.list_deals_for_contact(scope, contact.id)

    {:ok,
     assign(socket,
       page_title: contact.name,
       active_tab: :contacts,
       contact: contact,
       deals: deals
     )}
  end

  @impl true
  def handle_event("delete", _params, socket) do
    scope = socket.assigns.current_scope
    {:ok, _} = Contacts.delete_contact(scope, socket.assigns.contact)

    {:noreply,
     socket
     |> put_flash(:info, "Contact deleted successfully.")
     |> push_navigate(to: ~p"/contacts")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active_tab={@active_tab}>
      <div class="max-w-4xl mx-auto space-y-6">
        <div>
          <.link
            navigate={~p"/contacts"}
            class="inline-flex items-center gap-1.5 text-xs font-text tracking-[0.025em] text-fog hover:text-ash transition-colors mb-3"
          >
            <.icon name="hero-arrow-left" class="size-3.5" />
            <span>Back to contacts</span>
          </.link>
          <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
            <div>
              <h1 class="text-2xl font-semibold tracking-[-0.025em] text-chalk font-display">
                {@contact.name}
              </h1>
              <%= if @contact.company do %>
                <p class="mt-1 text-sm text-silver font-text tracking-[0.025em]">
                  {@contact.company}
                </p>
              <% end %>
            </div>
            <div class="flex items-center gap-3">
              <.button navigate={~p"/contacts/#{@contact}/edit"}>
                <.icon name="hero-pencil-square" class="size-4" />
                <span>Edit</span>
              </.button>
              <button
                type="button"
                phx-click="delete"
                data-confirm={"Are you sure you want to delete #{@contact.name}?"}
                class="inline-flex items-center justify-center gap-2 rounded-md bg-transparent px-4 py-2 text-sm font-medium font-text tracking-[0.025em] border border-rose-900/50 text-rose-400 hover:border-rose-700 hover:text-rose-300 transition-all shadow-subtle cursor-pointer"
              >
                <.icon name="hero-trash" class="size-4" />
                <span>Delete</span>
              </button>
            </div>
          </div>
        </div>

        <div class="rounded-md bg-graphite border border-basalt overflow-hidden shadow-subtle">
          <div class="border-b border-basalt bg-obsidian px-6 py-3">
            <h2 class="text-xs uppercase font-mono text-fog tracking-[0.025em]">Contact Details</h2>
          </div>
          <div class="p-6">
            <dl class="grid grid-cols-1 sm:grid-cols-2 gap-6">
              <div>
                <dt class="text-xs uppercase font-mono text-fog tracking-[0.025em]">Name</dt>
                <dd class="mt-1 text-sm font-medium text-chalk font-text tracking-[0.025em]">
                  {@contact.name}
                </dd>
              </div>

              <div>
                <dt class="text-xs uppercase font-mono text-fog tracking-[0.025em]">Company</dt>
                <dd class="mt-1 text-sm text-ash font-text tracking-[0.025em]">
                  {@contact.company || "—"}
                </dd>
              </div>

              <div>
                <dt class="text-xs uppercase font-mono text-fog tracking-[0.025em]">Email</dt>
                <dd class="mt-1 text-sm font-text tracking-[0.025em]">
                  <%= if @contact.email do %>
                    <a
                      href={"mailto:#{@contact.email}"}
                      class="text-link-blue hover:underline"
                    >
                      {@contact.email}
                    </a>
                  <% else %>
                    <span class="text-silver">—</span>
                  <% end %>
                </dd>
              </div>

              <div>
                <dt class="text-xs uppercase font-mono text-fog tracking-[0.025em]">Phone</dt>
                <dd class="mt-1 text-sm text-ash font-text tracking-[0.025em]">
                  <%= if @contact.phone do %>
                    <a
                      href={"tel:#{@contact.phone}"}
                      class="text-ash hover:text-chalk hover:underline"
                    >
                      {@contact.phone}
                    </a>
                  <% else %>
                    <span class="text-silver">—</span>
                  <% end %>
                </dd>
              </div>

              <div class="sm:col-span-2">
                <dt class="text-xs uppercase font-mono text-fog tracking-[0.025em]">Notes</dt>
                <dd class="mt-1 text-sm text-ash font-text tracking-[0.025em] whitespace-pre-wrap rounded-md bg-obsidian border border-basalt p-4">
                  {@contact.notes || "No notes provided."}
                </dd>
              </div>
            </dl>
          </div>
        </div>

        <div class="rounded-md bg-graphite border border-basalt overflow-hidden shadow-subtle">
          <div class="border-b border-basalt bg-obsidian px-6 py-4 flex items-center justify-between">
            <div>
              <h2 class="text-xs uppercase font-mono text-fog tracking-[0.025em]">Deals</h2>
              <p class="mt-0.5 text-xs text-silver font-text">
                Sales opportunities attached to this contact
              </p>
            </div>
            <%= if @deals != [] do %>
              <.button navigate={~p"/contacts/#{@contact}/deals/new"} variant="primary">
                <.icon name="hero-plus" class="size-4" />
                <span>New deal</span>
              </.button>
            <% end %>
          </div>
          <div class="p-6">
            <%= if @deals == [] do %>
              <div class="text-center py-8">
                <div class="inline-flex size-10 items-center justify-center rounded-xs bg-obsidian border border-basalt text-fog mb-3">
                  <.icon name="hero-banknotes" class="size-5" />
                </div>
                <h3 class="text-base font-medium text-chalk font-display mb-1">No deals yet</h3>
                <p class="text-xs text-fog font-text tracking-[0.025em] max-w-sm mx-auto mb-4">
                  Create a deal to track values, stages, and notes for opportunities with {@contact.name}.
                </p>
                <.button navigate={~p"/contacts/#{@contact}/deals/new"} variant="primary">
                  <.icon name="hero-plus" class="size-4" />
                  <span>New deal</span>
                </.button>
              </div>
            <% else %>
              <div class="overflow-x-auto">
                <table class="w-full text-left text-sm font-text">
                  <thead>
                    <tr class="border-b border-basalt text-xs font-mono uppercase text-fog tracking-[0.025em]">
                      <th class="pb-3 pr-4">Deal</th>
                      <th class="pb-3 px-4">Amount</th>
                      <th class="pb-3 px-4">Stage</th>
                      <th class="pb-3 pl-4 text-right">Action</th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-basalt">
                    <tr :for={deal <- @deals} class="hover:bg-obsidian/50 transition-colors">
                      <td class="py-3.5 pr-4">
                        <.link
                          navigate={~p"/deals/#{deal}"}
                          class="font-medium text-chalk hover:text-signal-green transition-colors"
                        >
                          {deal.title}
                        </.link>
                        <p :if={deal.notes} class="text-xs text-fog line-clamp-1 mt-0.5">
                          {deal.notes}
                        </p>
                      </td>
                      <td class="py-3.5 px-4 font-mono font-medium text-signal-green whitespace-nowrap">
                        {format_idr(deal.amount)}
                      </td>
                      <td class="py-3.5 px-4 whitespace-nowrap">
                        <.stage_badge name={deal.pipeline_column.name} />
                      </td>
                      <td class="py-3.5 pl-4 text-right whitespace-nowrap">
                        <.link
                          navigate={~p"/deals/#{deal}"}
                          class="inline-flex items-center gap-1 text-xs font-text text-fog hover:text-chalk transition-colors"
                        >
                          <span>View</span>
                          <.icon name="hero-chevron-right" class="size-3" />
                        </.link>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
