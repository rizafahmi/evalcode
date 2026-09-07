defmodule Alur.Repo do
  use Ecto.Repo,
    otp_app: :alur,
    adapter: Ecto.Adapters.SQLite3
end
