defmodule RefData.Server do
  @moduledoc false
  use GenServer

  alias RefData.{Data, Store}

  def start_link(opts) when is_list(opts) do
    opts = Keyword.validate!(opts, [:path, :name])
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    server_opts = if is_nil(name), do: [], else: [name: name]
    GenServer.start_link(__MODULE__, Keyword.fetch!(opts, :path), server_opts)
  end

  # Preserve the original start_link(path, opts) interface.
  def start_link(path) when is_binary(path), do: start_link(path, [])
  def start_link(path, opts), do: start_link(Keyword.put(opts, :path, path))

  @impl true
  def init(path) do
    case Data.load(path) do
      {:ok, datasets} -> {:ok, Store.new(datasets)}
      {:error, reason} -> {:stop, {:invalid_reference_data, reason}}
    end
  end

  # Local public reads bypass this mailbox. Keep messages for older integrations
  # and calls to servers on another node, where a local ETS lookup is impossible.
  @impl true
  def handle_call({:get_all_keys}, _from, table) do
    {:reply, :ets.lookup_element(table, :keys, 2), table}
  end

  def handle_call({:fetch, key}, _from, table),
    do: {:reply, Store.fetch_table(table, key), table}

  def handle_call({key}, _from, table), do: {:reply, get(table, key), table}

  def handle_call({key, disabled: disabled}, _from, table) do
    data = get(table, key)
    result = if data, do: RefData.Options.disable(data, disabled)
    {:reply, result, table}
  end

  defp get(table, key) do
    case Store.fetch_table(table, key) do
      {:ok, data} -> data
      :error -> nil
    end
  end
end
