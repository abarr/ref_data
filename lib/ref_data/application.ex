defmodule RefData.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      %{
        id: RefData.Server,
        start: {RefData.Server, :start_link, [Application.get_env(:ref_data, :dir, "ref_data")]}
      }
    ]

    opts = [strategy: :one_for_one, name: RefData.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
