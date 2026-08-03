defmodule WarungWeb.OrderParams do
  @moduledoc """
  Normalisation helpers for order form parameters and imported payloads.
  """

  @default_timeout 5_000

  def status_label(nil), do: "unknown"
  def status_label(status), do: to_string(status)

  def display_name(customer) do
    case customer do
      %{name: n} when is_binary(n) -> String.upcase(n)
      _ -> "ANONYMOUS"
    end
  end

  def timeout_for(opts) when is_map(opts) do
    Map.get(opts, :timeout, @default_timeout)
  end

  def third_field(row) when is_tuple(row) and tuple_size(row) >= 3, do: elem(row, 2)
  def third_field(row) when is_tuple(row), do: nil

  def currency_from(payload) when is_binary(payload) do
    case JSON.decode!(payload) do
      %{"currency" => currency} -> currency
      map when is_map(map) -> {:error, :missing_currency}
      _ -> {:error, :not_an_object}
    end
  end
end
