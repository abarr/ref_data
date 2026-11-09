defmodule RefData.Server do
  @moduledoc false
  use GenServer

  alias RefData.Data

  def start_link(opts) when is_list(opts) do
    opts = Keyword.validate!(opts, [:path, :name])
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    server_opts = if name, do: [name: name], else: []
    GenServer.start_link(__MODULE__, Keyword.fetch!(opts, :path), server_opts)
  end

  # Preserve the original start_link(path, opts) interface.
  def start_link(path) when is_binary(path), do: start_link(path, [])

  def start_link(path, opts), do: start_link(Keyword.put(opts, :path, path))

  @impl true
  def init(path) do
    case Data.load(path) do
      {:ok, datasets} -> {:ok, datasets}
      {:error, reason} -> {:stop, {:invalid_reference_data, reason}}
    end
  end

  @impl true
  def handle_call({:get_all_keys}, _from, state) do
    {:reply, state |> Map.keys() |> Enum.sort(), state}
  end

  def handle_call({:fetch, key}, _from, state), do: {:reply, Map.fetch(state, key), state}

  # Keep the original internal messages for existing integrations.
  def handle_call({key}, _from, state), do: {:reply, Map.get(state, key), state}

  def handle_call({key, disabled: disabled}, _from, state) do
    result =
      case Map.fetch(state, key) do
        {:ok, data} -> RefData.disable_options(data, disabled)
        :error -> nil
      end

    {:reply, result, state}
  end
end
