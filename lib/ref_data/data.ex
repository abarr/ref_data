defmodule RefData.Data do
  @moduledoc false

  @spec load(Path.t()) :: {:ok, map()} | {:error, String.t()}
  def load(dir) do
    with {:ok, paths} <- get_file_paths(dir) do
      load_ref_data(paths)
    end
  end

  def get_file_paths(dir) when is_binary(dir) do
    case File.ls(dir) do
      {:ok, files} ->
        paths =
          files
          |> Enum.filter(&(Path.extname(&1) == ".json"))
          |> Enum.sort()
          |> Enum.map(&Path.join(dir, &1))

        {:ok, paths}

      {:error, reason} ->
        {:error, "#{dir}: #{:file.format_error(reason)}"}
    end
  end

  def get_file_paths(_), do: {:error, "expected a directory path"}

  def load_ref_data(paths) when is_list(paths) do
    Enum.reduce_while(paths, {:ok, %{}}, fn path, {:ok, datasets} ->
      with {:ok, contents} <- File.read(path),
           {:ok, decoded} <- JSON.decode(contents),
           {:ok, name, data} <- standardise(decoded),
           false <- Map.has_key?(datasets, name) do
        {:cont, {:ok, Map.put(datasets, name, data)}}
      else
        true -> {:halt, {:error, "#{path}: duplicate dataset name"}}
        {:error, reason} -> {:halt, {:error, "#{path}: #{inspect(reason)}"}}
      end
    end)
  end

  def load_ref_data(_), do: {:error, "expected a list of file paths"}

  defp standardise(%{"name" => name, "data" => data}) when is_binary(name) do
    standardise(name, data)
  end

  defp standardise(map) when is_map(map) and map_size(map) == 1 do
    [{name, data}] = Map.to_list(map)
    standardise(name, data)
  end

  defp standardise(_), do: {:error, "expected a named dataset or a single-key object"}

  defp standardise(name, data) when is_binary(name) and is_list(data) do
    with {:ok, options} <- standardise_values(data) do
      {:ok, name, options}
    end
  end

  defp standardise(_, _), do: {:error, "dataset name must be a string and data must be a list"}

  defp standardise_values(values) do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, options} ->
      case standardise_value(value) do
        {:ok, option} -> {:cont, {:ok, [option | options]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, options} -> {:ok, Enum.reverse(options)}
      error -> error
    end
  end

  defp standardise_value(value) when is_binary(value), do: {:ok, [key: value, value: value]}

  defp standardise_value(%{"key" => key, "value" => value})
       when is_binary(key) and (is_binary(value) or is_number(value) or is_boolean(value)) do
    {:ok, [key: key, value: value]}
  end

  defp standardise_value(map) when is_map(map) and map_size(map) == 1 do
    [{label, values}] = Map.to_list(map)

    if is_binary(label) and is_list(values) do
      with {:ok, options} <- standardise_values(values) do
        {:ok, {label, options}}
      end
    else
      {:error, "group must contain a string label and a list of options"}
    end
  end

  defp standardise_value(_),
    do: {:error, "invalid option: expected a string, key/value object or group"}
end
