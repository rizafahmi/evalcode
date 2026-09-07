defmodule AlurWeb.AccountSessionHTML do
  @moduledoc """
  Renders sign-in pages for the AccountSessionController.
  """
  use AlurWeb, :html

  embed_templates "account_session_html/*"
end
