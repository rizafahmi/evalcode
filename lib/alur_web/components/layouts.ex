defmodule AlurWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use AlurWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash} current_scope={@current_scope}>
        <h1>Content</h1>
      </Layouts.app>

  The `current_scope` is the signed-in account (or `nil`), which decides
  whether the signed-in navigation bar is rendered.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the signed-in account scope (`nil` when logged out)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="flex min-h-screen flex-col bg-carbon text-ash">
      <header class="sticky top-0 z-30 border-b border-basalt bg-carbon/95 backdrop-blur">
        <div class="mx-auto flex h-14 w-full max-w-6xl items-center justify-between gap-4 px-4 sm:px-6 lg:px-8">
          <div class="flex items-center gap-3">
            <span class="inline-block size-2 rounded-xs bg-signal-green shadow-subtle" />
            <span class="font-display text-base font-semibold tracking-[-0.025em] text-chalk">
              Alur
            </span>
            <span class="hidden rounded-xs border border-moss-border bg-fern-ground px-1.5 py-0.5 font-mono text-[10px] uppercase tracking-[0.025em] text-signal-green sm:inline-block">
              crm
            </span>
          </div>

          <nav :if={@current_scope} class="flex items-center gap-1" aria-label="Main">
            <.link
              navigate={~p"/"}
              class="rounded-xs px-3 py-1.5 text-sm font-medium font-text tracking-[0.025em] text-fog transition-colors hover:bg-slate hover:text-ash"
            >
              Pipeline
            </.link>
            <.link
              navigate={~p"/contacts"}
              class="rounded-xs px-3 py-1.5 text-sm font-medium font-text tracking-[0.025em] text-fog transition-colors hover:bg-slate hover:text-ash"
            >
              Contacts
            </.link>
            <.link
              navigate={~p"/todos"}
              class="rounded-xs px-3 py-1.5 text-sm font-medium font-text tracking-[0.025em] text-fog transition-colors hover:bg-slate hover:text-ash"
            >
              To-dos
            </.link>
          </nav>

          <div :if={@current_scope} class="flex items-center gap-3">
            <span class="hidden font-mono text-xs tracking-[0.025em] text-fog sm:inline-block">
              {@current_scope.email}
            </span>
            <.link
              href={~p"/accounts/log-out"}
              method="delete"
              class="inline-flex items-center rounded-md border border-basalt px-3 py-1.5 text-sm font-medium font-text tracking-[0.025em] text-fog transition-colors hover:border-pewter hover:text-chalk"
            >
              Log out
            </.link>
          </div>
        </div>
      </header>

      <main class="flex-1">
        <div class="mx-auto w-full max-w-6xl px-4 py-8 sm:px-6 lg:px-8">
          {render_slot(@inner_block)}
        </div>
      </main>

      <footer class="border-t border-basalt py-4">
        <p class="mx-auto max-w-6xl px-4 font-mono text-xs tracking-[0.025em] text-fog sm:px-6 lg:px-8">
          Alur · your personal CRM
        </p>
      </footer>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title="We can't find the internet"
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Attempting to reconnect
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title="Something went wrong!"
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Attempting to reconnect
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
