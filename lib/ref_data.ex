defmodule RefData do
  @moduledoc """
  Loads JSON reference datasets for form options and submitted-value validation.

  Use supervised storage for shared, direct ETS reads, or load an immutable
  `RefData.Catalog` and pass it as `source: catalog` without starting a server.
  See the README for data formats, configuration and supervision examples.
  """

  alias RefData.{Catalog, Data, Options, Store}

  @type value :: String.t() | number() | boolean()
  @type option :: [key: String.t(), value: value(), disabled: boolean()]
  @type group :: {String.t(), [option() | group()]}
  @type options :: [option() | group()]
  @type source :: Catalog.t() | GenServer.server()
  @type lookup_options :: [disabled: [String.t()], server: GenServer.server(), source: source()]
  @type validation_error :: :unknown_dataset | :invalid_value | :disabled_value | :ambiguous_value

  @doc "Loads and validates a directory into an immutable catalog without starting a server."
  @spec load(Path.t()) :: {:ok, Catalog.t()} | {:error, String.t()}
  def load(path) do
    with {:ok, datasets} <- Data.load(path) do
      {:ok, %Catalog{datasets: datasets}}
    end
  end

  @doc "Starts shared storage. Requires `:path`; accepts `:name` to override the default server name."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts), do: RefData.Server.start_link(opts)

  @doc false
  def child_spec(opts) do
    %{id: Keyword.get(opts, :name) || __MODULE__, start: {__MODULE__, :start_link, [opts]}}
  end

  @doc "Returns dataset names in alphabetical order from a server or loaded catalog."
  @spec list_all_keys(source()) :: [String.t()]
  def list_all_keys(source \\ RefData.Server)
  def list_all_keys(%Catalog{} = catalog), do: Catalog.keys(catalog)
  def list_all_keys(server), do: Store.keys(server)

  @doc """
  Returns `{:ok, options}` or `:error` when the dataset does not exist.

  Local server lookups read directly from ETS. An unavailable server (including the
  default one when no `:path` is configured) exits with `:noproc`, rather than
  being treated as a missing dataset. Remote servers use
  messages because ETS tables cannot be read across nodes.
  """
  @spec fetch(String.t(), lookup_options()) :: {:ok, options()} | :error
  def fetch(key, opts \\ []) when is_binary(key) do
    validate_options!(opts)

    case fetch_source(source(opts), key) do
      {:ok, data} -> {:ok, Options.disable(data, Keyword.get(opts, :disabled, []))}
      :error -> :error
    end
  end

  @doc """
  Returns dataset options, or `nil` if the dataset does not exist.

  `:disabled` lists option labels (the `key` fields), including labels in groups.
  `:source` selects a loaded catalog or server. `:server` remains supported as an
  alternative for server selection; supplying both options raises `ArgumentError`.
  Neither option changes the stored data.
  """
  @spec get(String.t(), lookup_options()) :: options() | nil
  def get(key, opts \\ []) do
    case fetch(key, opts) do
      {:ok, data} -> data
      :error -> nil
    end
  end

  @doc "Returns dataset options, raising `KeyError` if the dataset does not exist."
  @spec get!(String.t(), lookup_options()) :: options()
  def get!(key, opts \\ []) do
    case fetch(key, opts) do
      {:ok, data} -> data
      :error -> raise KeyError, key: key, term: __MODULE__
    end
  end

  @doc """
  Validates a submitted option value and returns its canonical JSON scalar value.

  Strings are matched against the string representation of known values, so a
  browser submission of `"true"` can return `{:ok, true}`. Numeric and boolean
  inputs must match exactly, including type. Unknown values are never parsed or
  converted speculatively; `nil`, lists and maps are invalid.

  Matching uses option **values**, not labels, and recurses through groups. Options
  whose labels appear in `:disabled` are excluded. A duplicated value is allowed
  if any matching option is enabled. If a string represents several distinct
  enabled values (for example `true` and `"true"`), it is rejected as ambiguous.

  Returns `{:error, reason}` for an unknown dataset, invalid value, disabled value
  or ambiguous value. An unavailable server still exits, as with `fetch/2`.
  """
  @spec validate_value(String.t(), term(), lookup_options()) ::
          {:ok, value()} | {:error, validation_error()}
  def validate_value(key, submitted, opts \\ []) when is_binary(key) do
    validate_options!(opts)

    case fetch_source(source(opts), key) do
      {:ok, data} -> Options.validate(data, submitted, Keyword.get(opts, :disabled, []))
      :error -> {:error, :unknown_dataset}
    end
  end

  @doc "Returns whether a submitted value is valid and enabled. Accepts the same options as `validate_value/3`."
  @spec valid_value?(String.t(), term(), lookup_options()) :: boolean()
  def valid_value?(key, submitted, opts \\ []) do
    match?({:ok, _}, validate_value(key, submitted, opts))
  end

  @doc """
  Returns the label for a stored value, or `nil` if the dataset or value is unknown.

  Use it to display a value saved from a form, for example `"CA"` as `"Canada"`.
  Groups are searched too. A value of the same type is preferred; otherwise a
  string matches a value's string representation, as in `validate_value/3`. If
  several options share the value, the first label in the dataset is returned.
  Accepts `:source` or `:server`.
  """
  @spec label(String.t(), term(), source: source(), server: GenServer.server()) ::
          String.t() | nil
  def label(key, value, opts \\ []) when is_binary(key) do
    validate_options!(opts, [:server, :source])

    case fetch_source(source(opts), key) do
      {:ok, data} -> Options.label(data, value)
      :error -> nil
    end
  end

  @doc false
  defdelegate disable_options(data, disabled), to: Options, as: :disable

  defp source(opts), do: Keyword.get(opts, :source, Keyword.get(opts, :server, RefData.Server))
  defp fetch_source(%Catalog{} = catalog, key), do: Catalog.fetch(catalog, key)
  defp fetch_source(server, key), do: Store.fetch(server, key)

  defp validate_options!(opts, allowed \\ [:disabled, :server, :source]) do
    unless Keyword.keyword?(opts), do: raise(ArgumentError, "expected keyword options")
    Keyword.validate!(opts, allowed)

    if Keyword.has_key?(opts, :source) and Keyword.has_key?(opts, :server) do
      raise ArgumentError, "use either :source or :server, not both"
    end

    disabled = Keyword.get(opts, :disabled, [])

    unless is_list(disabled) and Enum.all?(disabled, &is_binary/1) do
      raise ArgumentError, ":disabled must be a list of option labels"
    end
  end

  @doc "Defines lookup and validation functions delegating to RefData. Accepts a `:server` option."
  defmacro __using__(opts) do
    server = Keyword.get(opts, :server, RefData.Server)

    quote do
      def list_all_keys, do: RefData.list_all_keys(unquote(server))
      def get(key, opts \\ []), do: RefData.get(key, ref_data_options(opts))
      def get!(key, opts \\ []), do: RefData.get!(key, ref_data_options(opts))
      def fetch(key, opts \\ []), do: RefData.fetch(key, ref_data_options(opts))

      def validate_value(key, submitted, opts \\ []),
        do: RefData.validate_value(key, submitted, ref_data_options(opts))

      def valid_value?(key, submitted, opts \\ []),
        do: RefData.valid_value?(key, submitted, ref_data_options(opts))

      def label(key, value, opts \\ []),
        do: RefData.label(key, value, ref_data_options(opts))

      defp ref_data_options(opts) do
        if Keyword.has_key?(opts, :source),
          do: opts,
          else: Keyword.put_new(opts, :server, unquote(server))
      end
    end
  end
end
