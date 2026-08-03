defmodule WarungWeb.OrderLive.Index do
  use WarungWeb, :live_view

  alias Warung.Catalog
  alias Warung.Orders

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Orders")
     |> assign(:products, Catalog.list_products())
     |> assign(:error, nil)
     |> stream(:orders, Orders.list_orders())}
  end

  @impl true
  def handle_event("place", params, socket) do
    with {:ok, attrs} <- build_attrs(params),
         {:ok, order} <- Orders.create_order(attrs) do
      {:noreply,
       socket
       |> assign(:error, nil)
       |> stream_insert(:orders, order, at: 0)}
    else
      _ -> {:noreply, assign(socket, :error, "That order could not be placed.")}
    end
  end

  # Form values arrive as strings and a submission can carry anything at all —
  # `min="1"` on the input is client-side only. Neither parsing nor anything
  # downstream of it may raise, so magnitude is bounded here: Elixir integers
  # are arbitrary precision, but SQLite's are 64-bit, and handing it a bignum
  # raises Exqlite.Error from inside the driver where `with` cannot catch it.
  @max_sqlite_int 9_223_372_036_854_775_807

  defp build_attrs(params) do
    with {product_id, ""} <- Integer.parse(params["product_id"] || ""),
         {quantity, ""} <- Integer.parse(params["quantity"] || ""),
         true <- in_range?(product_id) and in_range?(quantity) do
      {:ok,
       %{
         customer_email: params["customer_email"],
         items: [%{product_id: product_id, quantity: quantity}]
       }}
    else
      _ -> :error
    end
  end

  defp in_range?(n), do: n > 0 and n <= @max_sqlite_int

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-3xl p-6">
      <h1 class="text-2xl font-bold mb-6">Orders</h1>

      <form id="place-order" phx-submit="place" class="flex flex-wrap gap-2 mb-6">
        <input
          type="email"
          name="customer_email"
          placeholder="customer@example.com"
          class="input input-bordered"
        />
        <select name="product_id" class="select select-bordered">
          <option :for={product <- @products} value={product.id}>{product.name}</option>
        </select>
        <input type="number" name="quantity" value="1" min="1" class="input input-bordered w-24" />
        <button type="submit" class="btn btn-primary">Place order</button>
      </form>

      <p :if={@error} class="alert alert-error mb-4">{@error}</p>

      <table class="table">
        <thead>
          <tr>
            <th>Customer</th>
            <th>Items</th>
            <th>Total</th>
          </tr>
        </thead>
        <tbody id="orders" phx-update="stream">
          <tr :for={{dom_id, order} <- @streams.orders} id={dom_id}>
            <td>{order.customer_email}</td>
            <td>{length(order.items)}</td>
            <td>{order.total}</td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end
end
