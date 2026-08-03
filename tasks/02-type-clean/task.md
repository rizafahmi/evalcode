# Task: Make the code pass the type checker

`lib/warung_web/order_params.ex` does not compile cleanly. Elixir 1.20's type
checker reports problems in it.

Fix them. Every function must satisfy the contract below — these are the
contracts its callers rely on, and several of them the current code violates
by raising instead.

## Contracts

- `status_label/1` — `nil` gives `"unknown"`; anything else is stringified.
- `display_name/1` — a customer whose `:name` is a binary gives that name
  upcased; anything else gives `"ANONYMOUS"`.
- `timeout_for/1` — the `:timeout` value when the map has one, otherwise `5000`.
- `third_field/1` — the third element for a tuple that has one, otherwise `nil`.
- `currency_from/1` — takes a JSON string. An object with a `"currency"` key
  gives that value. An object without one gives `{:error, :missing_currency}`.
  A payload that decodes to anything other than an object gives
  `{:error, :not_an_object}`.

## Done means

- `mix compile --force --warnings-as-errors` exits 0
- `mix test` passes
- You have not silenced anything. Adding `@compile` or `@dialyzer` attributes
  to suppress warnings is not a fix and will be recorded as a failure.

Start by running `mix compile --force` and reading what the compiler tells you.
