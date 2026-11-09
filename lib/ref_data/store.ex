defmodule RefData.Store do
  @moduledoc false

  # Called only by the owner. Publish the table after all data has been inserted.
  def new(datasets) do
    table = :ets.new(__MODULE__, [:set, :protected, read_concurrency: true])
    :ets.insert(table, Map.to_list(datasets))
    :ets.insert(table, {:keys, datasets |> Map.keys() |> Enum.sort()})
    {:ok, _} = Registry.register(RefData.Registry, self(), table)
    table
  end

  def fetch(server, key), do: read(server, {:fetch, key}, &fetch_table(&1, key))
  def keys(server), do: read(server, {:get_all_keys}, &:ets.lookup_element(&1, :keys, 2))

  def fetch_table(table, key) do
    case :ets.lookup(table, key) do
      [{^key, data}] -> {:ok, data}
      [] -> :error
    end
  end

  defp read(server, message, reader) do
    case GenServer.whereis(server) do
      nil -> unavailable(server)
      pid when is_pid(pid) and node(pid) == node() -> read_local(pid, server, reader)
      _remote -> GenServer.call(server, message)
    end
  end

  defp read_local(pid, server, reader) do
    case Registry.lookup(RefData.Registry, pid) do
      [{^pid, table}] -> reader.(table)
      [] -> unavailable(server)
    end
  rescue
    # The owner (or registry) may stop between resolving its PID and reading ETS.
    ArgumentError -> unavailable(server)
  end

  defp unavailable(server), do: exit({:noproc, {__MODULE__, :read, [server]}})
end
