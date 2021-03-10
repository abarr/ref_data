defmodule RefData.Server do
  @moduledoc false

  use GenServer
  alias RefData.Data

  def start_link(arg, _opts \\ []) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(arg) do
    with {:ok, list_of_paths} <- Data.get_file_paths(arg),
         {:ok, list_of_maps} <- Data.load_ref_data(list_of_paths) do
      {:ok, list_of_maps}
    else
      {:error, msg} ->
        {:stop, "Reference Data definitions are invalid - #{msg}"}
    end
  end

  def handle_call({:get_all_keys}, _from, state) do
    keys = Enum.reduce(state, [], fn m, list -> [m.name | list] end)
    {:reply, keys, state}
  end

  def handle_call({key, disabled: disabled_list}, _from, state) do
    %{data: data} = Enum.find(state, fn m -> m.name == key end)

    list =
      Enum.into(data, [], fn [key: key, value: value] ->
        case Enum.member?(disabled_list, key) do
          true ->
            [key: key, value: value, disabled: true]

          _ ->
            [key: key, value: value]
        end
      end)

    {:reply, list, state}
  end

  def handle_call({key}, _from, state) do
    %{data: list} = Enum.find(state, fn m -> m.name == key end)
    {:reply, list, state}
  end
end
