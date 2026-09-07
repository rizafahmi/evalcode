defmodule AlurWeb.AppHTML do
  @moduledoc """
  Renders the `/app` page shell that hosts the Vue application.
  """

  use AlurWeb, :html

  embed_templates "app_html/*"
end
