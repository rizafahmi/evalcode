defmodule WarungWeb.OrderParams do
  @moduledoc """
  Normalisation helpers for order form parameters and imported payloads.
  """

  # 1. cross-clause narrowing: `status` cannot be nil in the second clause,
  #    so the is_nil/1 check is dead code.
  def status_label(status) do
    case status do
      nil ->
        "unknown"

      s ->
        if is_nil(s), do: "unknown", else: to_string(s)
    end
  end

  # 2. guard narrowing: the is_binary/1 check below is redundant in the true
  #    branch and wrong in the false branch, where it narrows `name` to
  #    "not a binary" and String.upcase/1 accepts only binaries. The `case`
  #    above sets up a plausible nil-or-binary value but is not what makes
  #    this warn — the if/else's own guard narrowing fires on its own, even
  #    with `name` unconstrained.
  def display_name(customer) do
    name =
      case customer do
        %{name: n} when is_binary(n) -> n
        _ -> nil
      end

    if is_binary(name) do
      String.upcase(name)
    else
      String.upcase(name)
    end
  end

  # 3. is_map_key / not_set(): inside this branch `:timeout` is known absent.
  def timeout_for(opts) when is_map(opts) do
    if not is_map_key(opts, :timeout) do
      opts.timeout
    else
      opts.timeout
    end
  end

  # 4. tuple arity bounds: the guard proves the tuple has exactly 2 elements,
  #    so it cannot have a third.
  def third_field(row) when tuple_size(row) == 2 do
    elem(row, 2)
  end

  # 5. guard narrowing: the is_list/1 guard narrows `list` to `list()`,
  #    which is disjoint from what Map.fetch!/2 accepts. JSON.decode!/1 is
  #    not what makes this warn — the guard fires on its own even on an
  #    unconstrained argument.
  def currency_from(payload) when is_binary(payload) do
    case JSON.decode!(payload) do
      list when is_list(list) -> Map.fetch!(list, "currency")
      map when is_map(map) -> Map.fetch!(map, "currency")
    end
  end
end
