defmodule AlurWeb.UserLive.Login do
  use AlurWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm space-y-6">
        <div class="text-center">
          <h1 class="text-2xl font-semibold tracking-[-0.025em] text-chalk font-display">
            Log in
          </h1>
          <p class="mt-2 text-sm text-fog font-text tracking-[0.025em]">
            <%= if @current_scope && @current_scope.user do %>
              You need to reauthenticate to perform sensitive actions on your account.
            <% else %>
              Don't have an account?
              <.link
                navigate={~p"/users/register"}
                class="text-signal-green hover:underline font-medium"
              >
                Sign up
              </.link>
              for an account now.
            <% end %>
          </p>
        </div>

        <div class="rounded-md bg-graphite border border-basalt p-6 shadow-subtle">
          <.form
            :let={f}
            for={@form}
            id="login_form_password"
            action={~p"/users/log-in"}
            phx-submit="submit_password"
            phx-change="validate"
            phx-trigger-action={@trigger_submit}
            class="space-y-4"
          >
            <.input
              readonly={!!(@current_scope && @current_scope.user)}
              field={f[:email]}
              type="email"
              label="Email"
              autocomplete="username"
              spellcheck="false"
              required
              phx-mounted={JS.focus()}
            />

            <.input
              field={f[:password]}
              type="password"
              label="Password"
              autocomplete="current-password"
              spellcheck="false"
              required
            />

            <.button variant="primary" class="w-full">
              Log in <span aria-hidden="true">&rarr;</span>
            </.button>
          </.form>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if socket.assigns[:current_scope] && socket.assigns.current_scope.user do
      {:ok, redirect(socket, to: ~p"/")}
    else
      email =
        Phoenix.Flash.get(socket.assigns.flash, :email) ||
          get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

      form = to_form(%{"email" => email}, as: "user")

      {:ok, assign(socket, form: form, trigger_submit: false)}
    end
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    {:noreply, assign(socket, form: to_form(user_params, as: "user"))}
  end

  @impl true
  def handle_event("submit_password", %{"user" => user_params}, socket) do
    {:noreply, assign(socket, form: to_form(user_params, as: "user"), trigger_submit: true)}
  end

  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end
end
