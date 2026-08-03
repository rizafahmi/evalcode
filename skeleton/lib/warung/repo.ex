defmodule Warung.Repo do
  use Ecto.Repo,
    otp_app: :warung,
    adapter: Ecto.Adapters.SQLite3
end
