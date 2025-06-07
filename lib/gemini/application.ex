defmodule Gemini.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Finch, name: Gemini.Client.HTTP},
      {Gemini.Streaming.Manager, []}
    ]

    opts = [strategy: :one_for_one, name: Gemini.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
