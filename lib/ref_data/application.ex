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

    children = [{Registry, keys: :unique, name: RefData.Registry} | children]
    Supervisor.start_link(children, strategy: :rest_for_one, name: RefData.Supervisor)
  end
end
