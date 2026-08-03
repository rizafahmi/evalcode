# 01-live-orders — authoring notes

Validated by hand on 2026-08-03 against the skeleton at the commit that
introduced `WarungWeb.OrderLive.Index`.

## What a correct solution does

1. `Warung.Orders.create_order/1` broadcasts `{:order_created, order}` on the
   `"orders"` topic via `Warung.PubSub`, after the transaction commits and with
   `items` already loaded.
2. `OrderLive.Index.mount/3` subscribes to `"orders"` when `connected?(socket)`.
3. `handle_info({:order_created, order}, socket)` calls
   `stream_insert(socket, :orders, order, at: 0)`.

## What the held-out tests catch

- **Broadcast in `handle_event` instead of the context** — passes everything the
  prompt describes, fails "an order created outside any LiveView still appears".
- **`stream_insert` without `at: 0`** — fails "a new order appears first",
  because `list_orders/0` is newest-first and the row lands at the bottom.
- **Re-running `list_orders/0` and resetting the stream** — usually still passes,
  and that is acceptable; it is a correct if wasteful solution.

## Not tested, deliberately

A double `stream_insert` of the same order does *not* produce two rows —
LiveView streams key on DOM id and replace in place. There is no held-out test
for "the placing session shows one row" because it cannot fail.
