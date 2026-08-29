defmodule Sorak.Repo do
  use Ecto.Repo,
    otp_app: :sorak,
    adapter: Ecto.Adapters.SQLite3
end
