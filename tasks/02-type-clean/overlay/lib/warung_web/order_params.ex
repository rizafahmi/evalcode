defmodule WarungWeb.OrderParams do
  @moduledoc """
  Normalisation helpers for order form parameters and imported payloads.
  """

  def status_label(status) do
    case status do
      nil ->
        "unknown"

      s ->
        if is_nil(s), do: "unknown", else: to_string(s)
    end
  end

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

  def timeout_for(opts) when is_map(opts) do
    if not is_map_key(opts, :timeout) do
      opts.timeout
    else
      opts.timeout
    end
  end

  def third_field(row) when tuple_size(row) == 2 do
    elem(row, 2)
  end

  def currency_from(payload) when is_binary(payload) do
    case JSON.decode!(payload) do
      list when is_list(list) -> Map.fetch!(list, "currency")
      map when is_map(map) -> Map.fetch!(map, "currency")
    end
  end
end
