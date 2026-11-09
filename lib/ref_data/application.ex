defmodule RefData.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children =
      if Application.get_env(:ref_data, :start_default_server, true) do
        [{RefData.Server, path: Application.get_env(:ref_data, :path, "ref_data")}]
      else
        []
      end

    Supervisor.start_link(children, strategy: :one_for_one, name: RefData.Supervisor)
  end
end
