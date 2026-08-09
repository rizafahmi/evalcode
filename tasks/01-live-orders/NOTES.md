# 01-live-orders — authoring notes

> **Spoiler.** This file spells out the full solution and what the held-out
> tests catch. Never give it to an agent you are measuring.

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

## Held-out file and module naming

The held-out file is `holdout/holdout_order_live_realtime_test.exs` and its
module is `WarungWeb.Holdout.OrderLiveRealtimeTest`. Both the `holdout_`
filename prefix and the `Holdout` module namespace are load-bearing, and the
rule applies to every task's held-out tests.

`grade` copies `holdout/*` straight into the run's `test/`. Before the rename
the module was `WarungWeb.OrderLiveRealtimeTest`, which is a name a model could
plausibly choose itself; the file was `order_live_realtime_test.exs`, which is
the path a model would plausibly write to. Either collision makes the whole
suite fail to compile:

```
error: cannot define module WarungWeb.OrderParamsTest because it is currently
being defined in test/order_params_test.exs:1
```

`mix test` then exits non-zero and the run scores `completed=no` — for a model
that did the task and then wrote a test for it. Writing tests for your own
change is the behaviour a benchmark should reward, so the grader must not be
able to punish it. Verified against task 02, which is where the collision is
most likely (see that task's NOTES).

## The row-order assertion is not keyed on the stream name

"a new order appears first in the list" originally scanned the rendered HTML
for `<tr id="orders-\d+">` and took the first match. That prefix comes from the
LiveView stream's name, which `task.md` only ever hints at — a model that
renamed the stream to `:live_orders` produced no match, and the destructuring
`[first_row | _] = ...` raised `MatchError`, scoring `no` for correct work.
It now compares where the two customer emails land in the rendered string:
the newer one must appear before the older one. That is the property the task
actually asks for, and it survives any DOM the model chooses.

## `async: false` is required, not stylistic

The held-out module writes to the database, and SQLite locks the whole file.
An `async: true` module racing the skeleton's own suite flakes roughly one run
in thirty — which the grader reports as a failed run, i.e. a model failure.
