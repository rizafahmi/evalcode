defmodule AlurWeb.ContactLive.Form do
  use AlurWeb, :live_view

  alias Alur.Contacts
  alias Alur.Contacts.Contact

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, active_tab: :contacts)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    contact = %Contact{}
    changeset = Contacts.change_contact(socket.assigns.current_scope, contact)

    socket
    |> assign(page_title: "New Contact", contact: contact)
    |> assign(:form, to_form(changeset))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    contact = Contacts.get_contact!(socket.assigns.current_scope, id)
    changeset = Contacts.change_contact(socket.assigns.current_scope, contact)

    socket
    |> assign(page_title: "Edit Contact", contact: contact)
    |> assign(:form, to_form(changeset))
  end

  @impl true
  def handle_event("validate", %{"contact" => contact_params}, socket) do
    changeset =
      socket.assigns.current_scope
      |> Contacts.change_contact(socket.assigns.contact, contact_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"contact" => contact_params}, socket) do
    save_contact(socket, socket.assigns.live_action, contact_params)
  end

  defp save_contact(socket, :new, contact_params) do
    case Contacts.create_contact(socket.assigns.current_scope, contact_params) do
      {:ok, _contact} ->
        {:noreply,
         socket
         |> put_flash(:info, "Contact created successfully.")
         |> push_navigate(to: ~p"/contacts")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_contact(socket, :edit, contact_params) do
    case Contacts.update_contact(
           socket.assigns.current_scope,
           socket.assigns.contact,
           contact_params
         ) do
      {:ok, contact} ->
        {:noreply,
         socket
         |> put_flash(:info, "Contact updated successfully.")
         |> push_navigate(to: ~p"/contacts/#{contact}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active_tab={@active_tab}>
      <div class="max-w-2xl mx-auto space-y-6">
        <div>
          <.link
            navigate={if @live_action == :new, do: ~p"/contacts", else: ~p"/contacts/#{@contact}"}
            class="inline-flex items-center gap-1.5 text-xs font-text tracking-[0.025em] text-fog hover:text-ash transition-colors mb-3"
          >
            <.icon name="hero-arrow-left" class="size-3.5" />
            <span>
              {if @live_action == :new, do: "Back to contacts", else: "Back to #{@contact.name}"}
            </span>
          </.link>
          <h1 class="text-2xl font-semibold tracking-[-0.025em] text-chalk font-display">
            {if @live_action == :new, do: "New contact", else: "Edit contact"}
          </h1>
          <p class="mt-1 text-sm text-fog font-text tracking-[0.025em]">
            {if @live_action == :new,
              do: "Add a person or organization to your network.",
              else: "Update details for #{@contact.name}."}
          </p>
        </div>

        <div class="rounded-md bg-graphite border border-basalt p-6 shadow-subtle">
          <.form
            for={@form}
            id="contact-form"
            phx-change="validate"
            phx-submit="save"
            class="space-y-4"
          >
            <.input
              field={@form[:name]}
              type="text"
              label="Name"
              placeholder="Full name or display name"
              required
            />
            <.input
              field={@form[:company]}
              type="text"
              label="Company"
              placeholder="e.g. PT Maju Bersama"
            />
            <.input
              field={@form[:email]}
              type="email"
              label="Email"
              placeholder="e.g. contact@example.com"
            />
            <.input
              field={@form[:phone]}
              type="tel"
              label="Phone"
              placeholder="e.g. +62 812-3456-7890"
            />
            <.input
              field={@form[:notes]}
              type="textarea"
              label="Notes"
              rows={4}
              placeholder="Context, background, notes on how you met..."
            />

            <div class="flex items-center justify-end gap-3 pt-4 border-t border-basalt">
              <.link
                navigate={if @live_action == :new, do: ~p"/contacts", else: ~p"/contacts/#{@contact}"}
                class="inline-flex items-center justify-center rounded-md bg-transparent px-4 py-2 text-sm font-medium font-text tracking-[0.025em] text-ash border border-basalt hover:border-pewter hover:text-chalk transition-all shadow-subtle"
              >
                Cancel
              </.link>
              <.button variant="primary" type="submit" phx-disable-with="Saving...">
                Save contact
              </.button>
            </div>
          </.form>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
