defmodule RefData.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    # Only start the default server when a path is configured, so that merely
    # depending on RefData never stops a host application from booting.
    children =
      case Application.fetch_env(:ref_data, :path) do
        {:ok, path} -> [{RefData.Server, path: path}]
        :error -> []
      end

    children = [{Registry, keys: :unique, name: RefData.Registry} | children]
    Supervisor.start_link(children, strategy: :rest_for_one, name: RefData.Supervisor)
  end
end
