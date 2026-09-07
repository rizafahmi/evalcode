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

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :active_tab, :atom,
    default: nil,
    doc: "the currently active navigation section (:pipeline, :contacts, :todos)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="border-b border-basalt bg-graphite/90 backdrop-blur sticky top-0 z-40">
      <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div class="flex h-14 items-center justify-between gap-4">
          <div class="flex items-center gap-6">
            <.link
              navigate={~p"/"}
              class="flex items-center gap-2 font-display text-base font-semibold tracking-[-0.025em] text-chalk hover:text-ash transition-colors"
            >
              Alur
            </.link>

            <%= if @current_scope && @current_scope.user do %>
              <nav class="flex items-center space-x-1" aria-label="Main Navigation">
                <.link
                  navigate={~p"/"}
                  class={[
                    "px-3 py-1.5 rounded-xs text-sm font-medium font-text tracking-[0.025em] transition-colors",
                    @active_tab == :pipeline &&
                      "text-chalk bg-obsidian border border-basalt shadow-subtle",
                    @active_tab != :pipeline && "text-fog hover:text-ash hover:bg-obsidian/50"
                  ]}
                >
                  Pipeline
                </.link>
                <.link
                  navigate={~p"/contacts"}
                  class={[
                    "px-3 py-1.5 rounded-xs text-sm font-medium font-text tracking-[0.025em] transition-colors",
                    @active_tab == :contacts &&
                      "text-chalk bg-obsidian border border-basalt shadow-subtle",
                    @active_tab != :contacts && "text-fog hover:text-ash hover:bg-obsidian/50"
                  ]}
                >
                  Contacts
                </.link>
                <.link
                  navigate={~p"/todos"}
                  class={[
                    "px-3 py-1.5 rounded-xs text-sm font-medium font-text tracking-[0.025em] transition-colors",
                    @active_tab == :todos &&
                      "text-chalk bg-obsidian border border-basalt shadow-subtle",
                    @active_tab != :todos && "text-fog hover:text-ash hover:bg-obsidian/50"
                  ]}
                >
                  To-dos
                </.link>
              </nav>
            <% end %>
          </div>

          <div class="flex items-center gap-3">
            <%= if @current_scope && @current_scope.user do %>
              <span class="font-mono text-xs text-silver hidden sm:inline-block">
                {@current_scope.user.email}
              </span>
              <.link
                href={~p"/users/log-out"}
                method="delete"
                class="inline-flex items-center justify-center rounded-md bg-transparent px-3 py-1.5 text-xs font-medium font-text tracking-[0.025em] text-ash border border-basalt hover:border-pewter hover:text-chalk transition-all shadow-subtle"
              >
                Log out
              </.link>
            <% else %>
              <.link
                navigate={~p"/users/log-in"}
                class="inline-flex items-center justify-center rounded-md bg-transparent px-3 py-1.5 text-xs font-medium font-text tracking-[0.025em] text-ash border border-basalt hover:border-pewter hover:text-chalk transition-all shadow-subtle"
              >
                Log in
              </.link>
              <.link
                navigate={~p"/users/register"}
                class="inline-flex items-center justify-center rounded-md bg-signal-green px-3.5 py-1.5 text-xs font-medium font-text tracking-[0.025em] text-carbon border border-led-green hover:brightness-105 transition-all shadow-subtle"
              >
                Register
              </.link>
            <% end %>
            <.theme_toggle />
          </div>
        </div>
      </div>
    </header>

    <main class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
      {render_slot(@inner_block)}
    </main>

    <.flash_group flash={@flash} />
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

  @doc """
  Provides dark vs light theme toggle.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="relative flex flex-row items-center rounded-md border border-basalt bg-obsidian p-0.5 shadow-subtle">
      <div class="absolute h-full w-1/3 rounded-xs bg-slate shadow-subtle transition-[left] left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3" />

      <button
        class="relative z-10 flex w-1/3 cursor-pointer items-center justify-center p-1.5 text-fog hover:text-ash"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
        aria-label="System theme"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4" />
      </button>

      <button
        class="relative z-10 flex w-1/3 cursor-pointer items-center justify-center p-1.5 text-fog hover:text-ash"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
        aria-label="Light theme"
      >
        <.icon name="hero-sun-micro" class="size-4" />
      </button>

      <button
        class="relative z-10 flex w-1/3 cursor-pointer items-center justify-center p-1.5 text-fog hover:text-ash"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
        aria-label="Dark theme"
      >
        <.icon name="hero-moon-micro" class="size-4" />
      </button>
    </div>
    """
  end
end
