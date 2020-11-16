defmodule RefData.Server do
  use GenServer

  def start_link(arg, opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, arg, name: name)
  end

  def init(arg) do
    table_name = :ets.new(:ref_data, [:named_table, read_concurrency: true])

    get_file_paths(arg)
    |> load_ref_data()

    {:ok, table_name}
  end

  def handle_call(_ref_data, _from, nil) do
    {:stop, "The Application was unable to load reference data", nil}
  end

  def handle_call({:all_keys}, _from, table_name) do
    {:reply, Enum.into(:ets.tab2list(table_name), [], fn {k, _v} -> k end), table_name}
  end

  def handle_call({key, :raw}, _from, table_name) do
    {:reply, :ets.lookup(table_name, key), table_name}
  end

  def handle_call({key, disabled: disabled_list}, _from, table_name) do
    disabled_list = capitalise_list(disabled_list)

    case :ets.lookup(table_name, key) do
      [{_key, value}] ->
        list =
          Enum.into(value, [], fn v -> {String.capitalize(v), String.downcase(v)} end)
          |> Enum.into([], fn {k, v} ->
            case Enum.member?(disabled_list, k) do
              true -> [key: k, value: v, disabled: true]
              _ -> [key: k, value: v]
            end
          end)

        {:reply, list, table_name}

      _ ->
        {:error, "Key: #{key} does not exist"}
    end
  end

  def handle_call(key, _from, table_name) do
    value = :ets.lookup(table_name, key)

    case is_grouped?(value) do
      true ->
        cond do
          !single_level?(value) ->
            {:error, "Incorrect format for #{key}"}

          true ->
            [{_key, list}] = value
            {:reply, return_grouped_values(list, []), table_name}
        end

      _ ->
        {:reply, return_values(value), table_name}
    end
  end

  defp return_grouped_values([], acc), do: acc

  defp return_grouped_values([h | t], acc) do
    [key] = Map.keys(h)
    values = Map.fetch!(h, key)

    acc =
      acc ++
        [
          "#{key}":
            Enum.into(values, [], fn v -> {v, String.downcase(v)} end)
            |> Enum.into([], fn {k, v} -> [key: k, value: v] end)
        ]

    return_grouped_values(t, acc)
  end


  defp return_values([{_key, value}]) do
    Enum.into(value, [], fn v -> {v, String.downcase(v)} end)
    |> Enum.into([], fn {k, v} -> [key: k, value: v] end)
  end

  defp single_level?([{_key, value}]) do
    map = List.first(value)
    [key] = Map.keys(map)

    case List.first(Map.fetch!(map, key)) do
      v when is_binary(v) -> true
      _ -> false
    end
  end

  defp is_grouped?([]), do: false
  defp is_grouped?([{_key, value}]) do
    value
    |> List.first()
    |> is_map()
  end

  defp load_ref_data([]), do: {:error, "Must be a list of strings"}

  defp load_ref_data(paths) when is_list(paths) do
    paths
    |> Enum.each(fn path ->
      path
      |> read_file()
      |> convert_json_to_map()
      |> validate_ref_data()
      |> save_ref_data()
    end)
  end

  defp load_ref_data(_), do: {:error, "Must be a list of strings"}

  defp save_ref_data(map) do
    [key] = Map.keys(map)
    values = Map.fetch!(map, key)
    :ets.insert(:ref_data, {key, values})
  end

  defp get_file_paths(dir) do
    "#{dir}/*.json"
    |> Path.wildcard()
    |> Enum.sort()
  end

  defp read_file(path) when is_binary(path) do
    File.read!(path)
  end

  defp convert_json_to_map(json) do
    Jason.decode!(json)
  end

  defp validate_ref_data(map) when is_map(map) do
    cond do
      !has_single_key(map) -> {:error, "Has multiple keys"}
      !has_list_of_values(map) -> {:error, "Must have list of values"}
      true -> map
    end
  end

  defp has_list_of_values(map) do
    [key] = Map.keys(map)
    values = Map.fetch!(map, key)

    case Enum.count(values) do
      n when n >= 1 -> true
      _ -> false
    end
  end

  defp has_single_key(map) do
    case Enum.count(Map.keys(map)) do
      n when n == 1 -> true
      _ -> false
    end
  end

  defp capitalise_list(list) do
    Enum.into(list, [], fn v -> String.capitalize(v) end)
  end
end
