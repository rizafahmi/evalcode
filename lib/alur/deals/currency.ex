defmodule Alur.Deals.Currency do
  @moduledoc """
  Helpers for formatting Indonesian Rupiah (IDR) currency values.
  """

  @doc """
  Formats an integer amount in Indonesian Rupiah with period thousand separators.

  ## Examples

      iex> Alur.Deals.Currency.format_idr(15_000_000)
      "Rp 15.000.000"

      iex> Alur.Deals.Currency.format_idr(0)
      "Rp 0"

      iex> Alur.Deals.Currency.format_idr(nil)
      "Rp 0"
  """
  def format_idr(nil), do: "Rp 0"

  def format_idr(amount) when is_integer(amount) do
    if amount < 0 do
      "-Rp " <> format_grouped(abs(amount))
    else
      "Rp " <> format_grouped(amount)
    end
  end

  def format_idr(amount) when is_binary(amount) do
    case Integer.parse(amount) do
      {int, ""} -> format_idr(int)
      _ -> "Rp 0"
    end
  end

  defp format_grouped(0), do: "0"

  defp format_grouped(n) when is_integer(n) do
    n
    |> Integer.to_string()
    |> String.reverse()
    |> String.graphemes()
    |> Enum.chunk_every(3)
    |> Enum.map_join(".", &Enum.join/1)
    |> String.reverse()
  end
end
