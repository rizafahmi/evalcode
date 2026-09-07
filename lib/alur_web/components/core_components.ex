defmodule AlurWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  At first glance, this module may seem daunting, but its goal is to provide
  core building blocks for your application, such as tables, forms, and
  inputs. The components consist mostly of markup and are well-documented
  with doc strings and declarative assigns. You may customize and style
  them in any way you want, based on your application growth and needs.

  The foundation for styling is Tailwind CSS, a utility-first CSS framework.
  Here are useful references:

    * [Tailwind CSS](https://tailwindcss.com) - the foundational framework
      we build on. You will use it for layout, sizing, flexbox, grid, and
      spacing.

    * [Heroicons](https://heroicons.com) - see `icon/1` for usage.

    * [Phoenix.Component](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html) -
      the component system used by Phoenix. Some components, such as `<.link>`
      and `<.form>`, are defined there.

  """
  use Phoenix.Component

  alias Phoenix.HTML.Form

  alias Phoenix.LiveView.JS

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class="fixed top-2 right-2 mr-2 w-80 sm:w-96 z-50"
      {@rest}
    >
      <div class={[
        "flex gap-3 rounded-md p-4 shadow-subtle border text-sm text-wrap font-text tracking-[0.025em]",
        @kind == :info &&
          "bg-forest-wash text-signal-green border-moss-border",
        @kind == :error &&
          "bg-plum-edge text-ash border-iris-border"
      ]}>
        <.icon
          :if={@kind == :info}
          name="hero-information-circle"
          class="size-5 shrink-0 text-signal-green"
        />
        <.icon
          :if={@kind == :error}
          name="hero-exclamation-circle"
          class="size-5 shrink-0 text-lilac-accent"
        />
        <div class="flex-1">
          <p :if={@title} class="font-semibold text-chalk">{@title}</p>
          <p>{msg}</p>
        </div>
        <button
          type="button"
          class="group self-start cursor-pointer text-fog hover:text-ash"
          aria-label="close"
        >
          <.icon name="hero-x-mark" class="size-5 opacity-60 group-hover:opacity-100" />
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders a button with navigation support.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" variant="primary">Send!</.button>
      <.button navigate={~p"/"}>Home</.button>
  """
  attr :rest, :global, include: ~w(href navigate patch method download name value disabled)
  attr :class, :string
  attr :variant, :string, values: ~w(primary)
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    variants = %{
      "primary" =>
        "bg-signal-green hover:brightness-105 active:brightness-95 text-carbon border border-led-green",
      nil => "bg-transparent hover:border-pewter hover:text-chalk text-ash border border-basalt"
    }

    assigns =
      assign_new(assigns, :class, fn ->
        [
          "inline-flex items-center justify-center gap-2 rounded-md px-4 py-2 text-sm font-medium font-text tracking-[0.025em] shadow-subtle transition-colors duration-150 cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed",
          Map.fetch!(variants, assigns[:variant])
        ]
      end)

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@class} {@rest}>
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button class={@class} {@rest}>
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information. Unsupported types, such as hidden and radio,
  are best written directly in your templates.

  ## Examples

      <.input field={@form[:email]} type="email" />
      <.input name="my-input" errors={["oh no!"]} />
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               search select tel text textarea time url week)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :class, :string, default: nil, doc: "the input class to use over defaults"
  attr :error_class, :string, default: nil, doc: "the input error class to use over defaults"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class="mb-2">
      <label class="flex items-center gap-2 text-sm leading-6 text-ash font-text tracking-[0.025em] cursor-pointer">
        <input type="hidden" name={@name} value="false" disabled={@rest[:disabled]} />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class={
            @class ||
              "rounded-xs border-basalt bg-obsidian text-signal-green focus:ring-moss-border checked:bg-signal-green checked:border-led-green"
          }
          {@rest}
        />
        {@label}
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class="mb-2">
      <label class="block text-sm font-medium leading-6 text-ash font-text tracking-[0.025em]">
        <span :if={@label} class="block mb-1">{@label}</span>
        <select
          id={@id}
          name={@name}
          class={[
            @class ||
              "block w-full rounded-md border border-basalt bg-obsidian py-2 px-3 text-ash placeholder:text-fog focus:border-moss-border focus:outline-none focus:ring-1 focus:ring-moss-border sm:text-sm font-text tracking-[0.025em] shadow-subtle",
            @errors != [] &&
              (@error_class || "border-rose-500 focus:border-rose-500 focus:ring-rose-500/20")
          ]}
          multiple={@multiple}
          {@rest}
        >
          <option :if={@prompt} value="">{@prompt}</option>
          {Form.options_for_select(@options, @value)}
        </select>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class="mb-2">
      <label class="block text-sm font-medium leading-6 text-ash font-text tracking-[0.025em]">
        <span :if={@label} class="block mb-1">{@label}</span>
        <textarea
          id={@id}
          name={@name}
          class={[
            @class ||
              "block w-full rounded-md border border-basalt bg-obsidian py-2 px-3 text-ash placeholder:text-fog focus:border-moss-border focus:outline-none focus:ring-1 focus:ring-moss-border sm:text-sm font-text tracking-[0.025em] shadow-subtle",
            @errors != [] &&
              (@error_class || "border-rose-500 focus:border-rose-500 focus:ring-rose-500/20")
          ]}
          {@rest}
        >{Form.normalize_value("textarea", @value)}</textarea>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <div class="mb-2">
      <label class="block text-sm font-medium leading-6 text-ash font-text tracking-[0.025em]">
        <span :if={@label} class="block mb-1">{@label}</span>
        <input
          type={@type}
          name={@name}
          id={@id}
          value={Form.normalize_value(@type, @value)}
          class={[
            @class ||
              "block w-full rounded-md border border-basalt bg-obsidian py-2 px-3 text-ash placeholder:text-fog focus:border-moss-border focus:outline-none focus:ring-1 focus:ring-moss-border sm:text-sm font-text tracking-[0.025em] shadow-subtle",
            @errors != [] &&
              (@error_class || "border-rose-500 focus:border-rose-500 focus:ring-rose-500/20")
          ]}
          {@rest}
        />
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # Helper used by inputs to generate form errors
  defp error(assigns) do
    ~H"""
    <p class="mt-1.5 flex gap-2 items-center text-sm text-rose-600 dark:text-rose-400">
      <.icon name="hero-exclamation-circle" class="size-5" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renders a header with title.
  """
  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "flex items-center justify-between gap-6", "pb-4"]}>
      <div>
        <h1 class="text-xl font-semibold leading-8 text-chalk font-display tracking-[-0.015em]">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="text-sm text-fog font-text tracking-[0.025em]">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc """
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id">{user.id}</:col>
        <:col :let={user} label="username">{user.username}</:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <div class="overflow-y-auto px-4 sm:overflow-visible sm:px-0">
      <table class="w-full text-left text-sm text-silver font-text tracking-[0.025em]">
        <thead class="border-b border-basalt text-xs uppercase text-fog font-medium tracking-[0.025em]">
          <tr>
            <th :for={col <- @col} class="py-3 px-4 font-medium">{col[:label]}</th>
            <th :if={@action != []} class="py-3 px-4">
              <span class="sr-only">Actions</span>
            </th>
          </tr>
        </thead>
        <tbody
          id={@id}
          phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}
          class="divide-y divide-basalt"
        >
          <tr
            :for={row <- @rows}
            id={@row_id && @row_id.(row)}
            class="even:bg-graphite/40 hover:bg-graphite transition-colors"
          >
            <td
              :for={col <- @col}
              phx-click={@row_click && @row_click.(row)}
              class={["py-3 px-4 text-ash", @row_click && "hover:cursor-pointer"]}
            >
              {render_slot(col, @row_item.(row))}
            </td>
            <td :if={@action != []} class="w-0 py-3 px-4 font-semibold whitespace-nowrap">
              <div class="flex gap-4">
                <%= for action <- @action do %>
                  {render_slot(action, @row_item.(row))}
                <% end %>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title">{@post.title}</:item>
        <:item title="Views">{@post.views}</:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <ul class="divide-y divide-basalt border-y border-basalt">
      <li :for={item <- @item} class="flex items-center justify-between py-3">
        <div>
          <div class="font-medium text-chalk font-text tracking-[0.025em]">{item.title}</div>
          <div class="text-sm text-silver font-text tracking-[0.025em]">{render_slot(item)}</div>
        </div>
      </li>
    </ul>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  your compiled app.css by the plugin in `assets/vendor/heroicons.js`.

  ## Examples

      <.icon name="hero-x-mark" />
      <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :string, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # You can make use of gettext to translate error messages by
    # uncommenting and adjusting the following code:

    # if count = opts[:count] do
    #   Gettext.dngettext(AlurWeb.Gettext, "errors", msg, msg, count, opts)
    # else
    #   Gettext.dgettext(AlurWeb.Gettext, "errors", msg, opts)
    # end

    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end

  @doc """
  Formats an amount into Indonesian Rupiah (e.g. "Rp 15.000.000").
  """
  defdelegate format_idr(amount), to: Alur.Deals.Currency

  @doc """
  Formats an activity timestamp into Indonesian time (WIB).
  """
  defdelegate format_activity_time(dt), to: Alur.Activities

  @doc """
  Formats a next action's due date and optional time.
  """
  defdelegate format_due(next_action), to: Alur.NextActions

  @doc """
  Checks if a next action is overdue.
  """
  defdelegate overdue?(next_action), to: Alur.NextActions

  @doc """
  Renders a stage badge for deals and pipeline columns.
  """
  attr :name, :string, required: true
  attr :class, :string, default: nil

  def stage_badge(assigns) do
    colors = %{
      "Lead" => "bg-slate border-basalt text-ash",
      "Meeting" => "bg-slate border-link-blue/40 text-link-blue",
      "Proposal" => "bg-plum-edge border-iris-border text-lavender-mist",
      "Won" => "bg-fern-ground border-moss-border text-signal-green",
      "Lost" => "bg-rose-950/40 border-rose-900/50 text-rose-400"
    }

    style = Map.get(colors, assigns.name, "bg-slate border-basalt text-ash")
    assigns = assign(assigns, :style, style)

    ~H"""
    <span class={[
      "inline-flex items-center rounded-xs px-2 py-0.5 text-xs font-mono tracking-[0.025em] border font-medium",
      @style,
      @class
    ]}>
      {@name}
    </span>
    """
  end
end
