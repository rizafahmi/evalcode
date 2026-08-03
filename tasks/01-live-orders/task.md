# Task: Make the orders dashboard live

The orders dashboard at `/orders` lists orders and lets you place one. Right
now, an order placed in one browser tab does not show up in any other tab
until that tab is reloaded.

Change that. When an order is placed, it should appear immediately in every
connected session, without a refresh.

## What you have

- `Warung.Orders.create_order/1` — creates an order, returns `{:ok, order}` with items preloaded
- `Warung.Orders.list_orders/0` — all orders, newest first, items preloaded
- `WarungWeb.OrderLive.Index` — the dashboard, already using a stream named `:orders`
- `Phoenix.PubSub` is already running as `Warung.PubSub` (see `lib/warung/application.ex`)

## Done means

- Two sessions open at `/orders`; placing an order in one makes it appear in the other, live
- Existing tests still pass

Run the suite with `mix test`.
