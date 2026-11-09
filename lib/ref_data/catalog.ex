defmodule RefData.Catalog do
  @moduledoc """
  An immutable snapshot of reference datasets returned by `RefData.load/1`.

  Pass it as `source: catalog` to lookup and validation functions, or directly to
  `RefData.list_all_keys/1`. No server or ETS table is required for these operations.
  """

  @opaque t :: %__MODULE__{datasets: %{String.t() => RefData.options()}}
  @enforce_keys [:datasets]
  defstruct [:datasets]

  @doc false
  def fetch(%__MODULE__{datasets: datasets}, key), do: Map.fetch(datasets, key)

  @doc false
  def keys(%__MODULE__{datasets: datasets}), do: datasets |> Map.keys() |> Enum.sort()
end
