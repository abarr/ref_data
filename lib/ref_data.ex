defmodule RefData do
  @moduledoc """
  Reference data for forms, loaded from JSON files instead of database tables.

  RefData turns each JSON file in a directory into a named dataset and gives you
  three things for it:

    * `get/2` returns options ready for a Phoenix select input.
    * `validate_value/3` checks a submitted value against the dataset.
    * `label/3` returns the label for a value you stored earlier.

  ## Setting up

  Create `priv/ref_data/` with `mix ref_data.init`, then point RefData at it in
  `config/runtime.exs`:

      config :ref_data, path: Application.app_dir(:my_app, "priv/ref_data")

  Datasets are loaded into ETS when your application starts, and any process can
  read them by name. The examples in this module assume these files:

      # titles.json - labels and values are the same
      {"titles": ["Dr", "Mr", "Mrs", "Ms", "Mx"]}

      # plans.json - a label (`key`) and the value to store
      {"plans": [
        {"key": "Starter", "value": "starter"},
        {"key": "Pro", "value": "pro"},
        {"key": "Legacy", "value": "legacy"}
      ]}

      # payment_terms.json - values keep their JSON types
      {"payment_terms": [
        {"key": "Net 7", "value": 7},
        {"key": "Net 30", "value": 30},
        {"key": "Net 60", "value": 60}
      ]}

      # countries_by_region.json - groups
      {"countries_by_region": [
        {"Oceania": [{"key": "Australia", "value": "AU"}, {"key": "New Zealand", "value": "NZ"}]},
        {"Americas": [{"key": "Canada", "value": "CA"}]}
      ]}

  A fifth, `countries.json`, holds the same three countries without groups.

  ## Where the data comes from

  Every lookup reads from a *source*:

    * The default server, started when `:path` is configured. This is what a
      call without options uses.
    * A server you supervise yourself with `{RefData, path: path, name: name}`,
      selected with `server: name`.
    * A catalog returned by `load/1`, selected with `source: catalog`. It needs
      no process and suits scripts, jobs and tests.

  All three behave the same for lookups, labels and validation. The README
  covers the data formats and the trade-offs between sources in more detail.
  """

  alias RefData.{Catalog, Data, Options, Store}

  @typedoc "A value submitted by a form and stored by your application."
  @type value :: String.t() | number() | boolean()

  @typedoc """
  One choice: its label under `:key` and its value under `:value`.

  `disabled: true` is appended when the label was listed in the `:disabled` option.
  """
  @type option :: [key: String.t(), value: value(), disabled: boolean()]

  @typedoc "A labelled group of options, rendered as an `<optgroup>`."
  @type group :: {String.t(), [option() | group()]}

  @typedoc "A dataset in the shape `Phoenix.HTML.Form.options_for_select/2` accepts."
  @type options :: [option() | group()]

  @typedoc "Where to read datasets from: a loaded catalog, or the name or PID of a server."
  @type source :: Catalog.t() | GenServer.server()

  @typedoc """
  Options accepted by lookups and validation.

    * `:disabled` - labels of options to mark as disabled.
    * `:source` - a catalog or server to read from.
    * `:server` - a server to read from; an alternative to `:source`.
  """
  @type lookup_options :: [disabled: [String.t()], server: GenServer.server(), source: source()]

  @typedoc """
  Why `validate_value/3` rejected a value.

    * `:unknown_dataset` - no dataset has that name.
    * `:invalid_value` - no option has that value.
    * `:disabled_value` - every option with that value is disabled.
    * `:ambiguous_value` - a string matches several different values.
  """
  @type validation_error :: :unknown_dataset | :invalid_value | :disabled_value | :ambiguous_value

  @doc """
  Loads a directory of JSON files into an immutable catalog without starting a server.

  Pass the catalog to other functions as `source: catalog`. Loading does not
  change the shared storage, and the catalog does not notice later file changes;
  call `load/1` again for a fresh snapshot.

  ## Examples

      {:ok, catalog} = RefData.load("priv/ref_data")

      RefData.list_all_keys(catalog)
      # => ["countries", "countries_by_region", "payment_terms", "plans", "titles"]

      RefData.get("countries", source: catalog)
      RefData.validate_value("payment_terms", "30", source: catalog)
      RefData.label("countries", "CA", source: catalog)

  A missing directory or an invalid file returns an error naming the path:

      RefData.load("missing")
      # => {:error, "missing: no such file or directory"}
  """
  @spec load(Path.t()) :: {:ok, Catalog.t()} | {:error, String.t()}
  def load(path) do
    with {:ok, datasets} <- Data.load(path) do
      {:ok, %Catalog{datasets: datasets}}
    end
  end

  @doc """
  Starts shared storage for the datasets in a directory.

  You rarely call this directly. Configure `:path` to have RefData start a default
  server for you, or add RefData to your own supervision tree.

  ## Options

    * `:path` - the directory to load. Required.
    * `:name` - the name to register. Defaults to the name used by lookups without
      options. Pass `nil` for an unnamed server that you query by PID.

  ## Examples

      children = [
        {RefData, name: MyApp.ReferenceData, path: Application.app_dir(:my_app, "priv/ref_data")}
      ]

      RefData.get("countries", server: MyApp.ReferenceData)

  Startup fails if the directory is missing or a file is invalid.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts), do: RefData.Server.start_link(opts)

  @doc false
  def child_spec(opts) do
    %{id: Keyword.get(opts, :name) || __MODULE__, start: {__MODULE__, :start_link, [opts]}}
  end

  @doc """
  Returns dataset names in alphabetical order.

  Pass a catalog or a server to list its datasets instead of the default server's.

  ## Examples

      iex> RefData.list_all_keys()
      ["countries", "countries_by_region", "payment_terms", "plans", "titles"]

  With `use RefData, server: MyApp.Billing.RefData` or a catalog, pass the source:

      RefData.list_all_keys(MyApp.Billing.RefData)
      RefData.list_all_keys(catalog)
  """
  @spec list_all_keys(source()) :: [String.t()]
  def list_all_keys(source \\ RefData.Server)
  def list_all_keys(%Catalog{} = catalog), do: Catalog.keys(catalog)
  def list_all_keys(server), do: Store.keys(server)

  @doc """
  Returns `{:ok, options}` or `:error` when the dataset does not exist.

  Accepts the same options as `get/2`.

  Local server lookups read directly from ETS. An unavailable server (including the
  default one when no `:path` is configured) exits with `:noproc`, rather than
  being treated as a missing dataset. Remote servers use messages because ETS
  tables cannot be read across nodes.

  ## Examples

  Given `payment_terms.json`:

  ```json
  {"payment_terms": [
    {"key": "Net 7", "value": 7},
    {"key": "Net 30", "value": 30},
    {"key": "Net 60", "value": 60}
  ]}
  ```

      iex> RefData.fetch("payment_terms")
      {:ok, [[key: "Net 7", value: 7], [key: "Net 30", value: 30], [key: "Net 60", value: 60]]}

      iex> RefData.fetch("missing")
      :error
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

  The result can be passed straight to a Phoenix select input.

  ## Options

    * `:disabled` - labels (the `key` fields) of options to mark as disabled,
      including labels inside groups. The stored data is not changed.
    * `:source` - a catalog or server to read from.
    * `:server` - a server to read from. Supplying both `:source` and `:server`
      raises `ArgumentError`.

  ## Examples

  Given `plans.json`:

  ```json
  {"plans": [
    {"key": "Starter", "value": "starter"},
    {"key": "Pro", "value": "pro"},
    {"key": "Legacy", "value": "legacy"}
  ]}
  ```

      iex> RefData.get("plans")
      [
        [key: "Starter", value: "starter"],
        [key: "Pro", value: "pro"],
        [key: "Legacy", value: "legacy"]
      ]

  Disable an option by label, for example a plan that is no longer sold:

      iex> RefData.get("plans", disabled: ["Legacy"])
      [
        [key: "Starter", value: "starter"],
        [key: "Pro", value: "pro"],
        [key: "Legacy", value: "legacy", disabled: true]
      ]

  Groups are returned as `{label, options}` tuples. Given `countries_by_region.json`:

  ```json
  {"countries_by_region": [
    {"Oceania": [{"key": "Australia", "value": "AU"}, {"key": "New Zealand", "value": "NZ"}]},
    {"Americas": [{"key": "Canada", "value": "CA"}]}
  ]}
  ```

      iex> RefData.get("countries_by_region")
      [
        {"Oceania", [[key: "Australia", value: "AU"], [key: "New Zealand", value: "NZ"]]},
        {"Americas", [[key: "Canada", value: "CA"]]}
      ]

  A dataset that does not exist:

      iex> RefData.get("missing")
      nil
  """
  @spec get(String.t(), lookup_options()) :: options() | nil
  def get(key, opts \\ []) do
    case fetch(key, opts) do
      {:ok, data} -> data
      :error -> nil
    end
  end

  @doc """
  Returns dataset options, raising `KeyError` if the dataset does not exist.

  Accepts the same options as `get/2`. Use it when a missing dataset is a bug,
  such as a name written in a template.

  ## Examples

  Given `payment_terms.json`:

  ```json
  {"payment_terms": [
    {"key": "Net 7", "value": 7},
    {"key": "Net 30", "value": 30},
    {"key": "Net 60", "value": 60}
  ]}
  ```

      iex> RefData.get!("payment_terms")
      [[key: "Net 7", value: 7], [key: "Net 30", value: 30], [key: "Net 60", value: 60]]

      RefData.get!("missing")
      # raises KeyError in the caller; the server keeps running
  """
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
  or ambiguous value; see `t:validation_error/0`. An unavailable server still
  exits, as with `fetch/2`. Accepts the same options as `get/2`.

  ## Examples

  Given `payment_terms.json`:

  ```json
  {"payment_terms": [
    {"key": "Net 7", "value": 7},
    {"key": "Net 30", "value": 30},
    {"key": "Net 60", "value": 60}
  ]}
  ```

  A browser submits the string `"30"`; the stored number comes back:

      iex> RefData.validate_value("payment_terms", "30")
      {:ok, 30}

  `45` is not a stored value, and `"Net 30"` is a label rather than a value:

      iex> RefData.validate_value("payment_terms", "45")
      {:error, :invalid_value}

      iex> RefData.validate_value("payment_terms", "Net 30")
      {:error, :invalid_value}

  Pass the same `:disabled` labels you rendered the form with. Here the value `30`
  is stored, but its label is disabled:

      iex> RefData.validate_value("payment_terms", "30", disabled: ["Net 30"])
      {:error, :disabled_value}

  A dataset that does not exist:

      iex> RefData.validate_value("missing", "30")
      {:error, :unknown_dataset}
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

  @doc """
  Returns whether a submitted value is valid and enabled.

  A boolean form of `validate_value/3` with the same rules and options. It returns
  `false` for every validation error, including an unknown dataset.

  ## Examples

  Given `plans.json`:

  ```json
  {"plans": [
    {"key": "Starter", "value": "starter"},
    {"key": "Pro", "value": "pro"},
    {"key": "Legacy", "value": "legacy"}
  ]}
  ```

      iex> RefData.valid_value?("plans", "pro")
      true

  `"enterprise"` is not stored, and `"Pro"` is a label rather than a value:

      iex> RefData.valid_value?("plans", "enterprise")
      false

      iex> RefData.valid_value?("plans", "Pro")
      false

  `"legacy"` is stored, but its label is disabled:

      iex> RefData.valid_value?("plans", "legacy", disabled: ["Legacy"])
      false
  """
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

  ## Examples

  Given `payment_terms.json`:

  ```json
  {"payment_terms": [
    {"key": "Net 7", "value": 7},
    {"key": "Net 30", "value": 30},
    {"key": "Net 60", "value": 60}
  ]}
  ```

  The stored number `30`, or the string `"30"` from a form, finds its label:

      iex> RefData.label("payment_terms", 30)
      "Net 30"

      iex> RefData.label("payment_terms", "30")
      "Net 30"

  `45` is not stored, so it has no label:

      iex> RefData.label("payment_terms", 45)
      nil

  A dataset that does not exist:

      iex> RefData.label("missing", 30)
      nil
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

  @doc """
  Defines a module of lookup and validation functions that delegate to RefData.

  The module gets `list_all_keys/0`, `get/2`, `get!/2`, `fetch/2`, `label/3`,
  `validate_value/3` and `valid_value?/3`, each with the options argument
  optional. Pass `:server` to bind the module to a server you supervise.

  ## Examples

      defmodule MyApp.RefData do
        use RefData
      end

      MyApp.RefData.get("countries")

      defmodule MyApp.Billing.Options do
        use RefData, server: MyApp.Billing.RefData
      end

      MyApp.Billing.Options.label("plans", "pro")

  A lookup can still name a catalog with `source: catalog`, which takes the place
  of the module's server for that call.
  """
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
