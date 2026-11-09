defmodule RefData.Options do
  @moduledoc false

  def disable(data, []), do: data
  def disable(data, disabled), do: disable_options(data, MapSet.new(disabled))

  def validate(data, submitted, disabled) do
    disabled = MapSet.new(disabled)
    matches = data |> flatten() |> Enum.filter(&matches?(&1[:value], submitted))

    allowed =
      matches
      |> Enum.reject(&MapSet.member?(disabled, &1[:key]))
      |> Enum.map(& &1[:value])
      |> Enum.uniq()

    case {matches, allowed} do
      {[], _} -> {:error, :invalid_value}
      {_, []} -> {:error, :disabled_value}
      {_, [value]} -> {:ok, value}
      _ -> {:error, :ambiguous_value}
    end
  end

  # An exact match wins; otherwise a string may match a value's string form.
  def label(data, value) do
    options = flatten(data)

    option =
      Enum.find(options, &(&1[:value] === value)) ||
        Enum.find(options, &matches?(&1[:value], value))

    if option, do: option[:key]
  end

  defp matches?(value, submitted) when is_binary(submitted),
    do: to_string(value) == submitted

  defp matches?(value, submitted), do: value === submitted

  defp flatten(options) do
    Enum.flat_map(options, fn
      {_label, values} -> flatten(values)
      option -> [option]
    end)
  end

  defp disable_options(data, disabled) do
    Enum.map(data, fn
      {label, values} ->
        {label, disable_options(values, disabled)}

      [key: key, value: _value] = option ->
        if MapSet.member?(disabled, key), do: option ++ [disabled: true], else: option
    end)
  end
end
