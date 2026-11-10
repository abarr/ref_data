# RefData

[![Elixir CI](https://github.com/abarr/ref_data/actions/workflows/elixir.yml/badge.svg)](https://github.com/abarr/ref_data/actions/workflows/elixir.yml)

Most applications have short lists that rarely change: countries, titles, payment
terms, subscription plans. RefData keeps those lists in JSON files in your project
instead of database tables, and gives you three things for each one:

- **options** for a select input,
- **validation** of the value a form submits, and
- the **label** for a value you stored earlier.

It has no runtime dependencies.

## Installation

Add RefData to your dependencies. It requires Elixir 1.18 or later.

```elixir
def deps do
  [{:ref_data, "~> 0.3.0"}]
end
```

## Quick start with Phoenix

This walks one field, a customer's country, through a form: rendering the choices,
validating the submission, and displaying the stored value.

**1. Create a dataset.** Run `mix ref_data.init` to create `priv/ref_data/`, then add
`priv/ref_data/countries.json`. Each option has a label to show (`key`) and a value
to store (`value`):

```json
{
  "name": "countries",
  "data": [
    {"key": "Australia", "value": "AU"},
    {"key": "Canada", "value": "CA"},
    {"key": "New Zealand", "value": "NZ"}
  ]
}
```

**2. Tell RefData where it is**, in `config/runtime.exs`:

```elixir
config :ref_data, path: Application.app_dir(:my_app, "priv/ref_data")
```

**3. Render the choices.** `RefData.get/2` returns options in the shape Phoenix
select inputs accept:

```heex
<.input field={@form[:country]} type="select" options={RefData.get("countries")} prompt="Choose a country" />
```

**4. Validate the submission.** Never trust that a submitted value came from your
list. In an Ecto changeset:

```elixir
def changeset(customer, attrs) do
  customer
  |> cast(attrs, [:country])
  |> validate_change(:country, fn :country, value ->
    if RefData.valid_value?("countries", value), do: [], else: [country: "is not a valid choice"]
  end)
end
```

**5. Display the stored value.** The database holds `"CA"`; show the label:

```heex
<p>Country: {RefData.label("countries", @customer.country)}</p>
```

That is the whole workflow. The rest of this document covers each part in detail.

## Writing datasets

Each `.json` file in the directory defines one dataset. RefData loads them when your
application starts; restart the application to pick up changed files.

Two words are used throughout:

- A **dataset name** identifies a list, such as `"countries"`. It is the first
  argument to every function. (`list_all_keys/0` returns dataset names.)
- An option's **label** is the text a person sees. In JSON and in returned options it
  is the `key` field, next to the `value` that gets submitted and stored.

The examples in this document use the five files below.

**A plain list**, when the label and the stored value are the same. `titles.json`:

```json
{"titles": ["Dr", "Mr", "Mrs", "Ms", "Mx"]}
```

**Labels with separate values**, when you store a code. `plans.json`:

```json
{
  "plans": [
    {"key": "Starter", "value": "starter"},
    {"key": "Pro", "value": "pro"},
    {"key": "Legacy", "value": "legacy"}
  ]
}
```

**Numbers and booleans** keep their JSON types, so you store `30`, not `"30"`.
`payment_terms.json`:

```json
{
  "payment_terms": [
    {"key": "Net 7", "value": 7},
    {"key": "Net 30", "value": 30},
    {"key": "Net 60", "value": 60}
  ]
}
```

**Groups**, which render as `<optgroup>` elements. `countries_by_region.json`:

```json
{
  "countries_by_region": [
    {"Oceania": [
      {"key": "Australia", "value": "AU"},
      {"key": "New Zealand", "value": "NZ"}
    ]},
    {"Americas": [
      {"key": "Canada", "value": "CA"}
    ]}
  ]
}
```

The fifth file is `countries.json` from the quick start. It uses the alternative
`{"name": ..., "data": [...]}` layout, which means the same as the single-key form.

The rules:

- Dataset names must be unique across the directory.
- Labels must be strings. Values may be strings, numbers or booleans.
- Option order is preserved.
- A group may hold plain strings or labelled options, and groups may be nested.
- Empty datasets and empty groups are allowed.
- An invalid file stops loading with an error that names the file.

## Everyday use

Every `iex>` example below, and in the function documentation, runs as part of the
test suite against the five files above.

### Select options

`get/2` returns a dataset ready for a select input. A plain list gives each option
the same label and value.

Stored in `titles.json`:

```json
{"titles": ["Dr", "Mr", "Mrs", "Ms", "Mx"]}
```

```elixir
iex> RefData.get("titles")
[
  [key: "Dr", value: "Dr"],
  [key: "Mr", value: "Mr"],
  [key: "Mrs", value: "Mrs"],
  [key: "Ms", value: "Ms"],
  [key: "Mx", value: "Mx"]
]
```

Groups come back as `{label, options}` tuples.

Stored in `countries_by_region.json`:

```json
{"countries_by_region": [
  {"Oceania": [{"key": "Australia", "value": "AU"}, {"key": "New Zealand", "value": "NZ"}]},
  {"Americas": [{"key": "Canada", "value": "CA"}]}
]}
```

```elixir
iex> RefData.get("countries_by_region")
[
  {"Oceania", [[key: "Australia", value: "AU"], [key: "New Zealand", value: "NZ"]]},
  {"Americas", [[key: "Canada", value: "CA"]]}
]
```

Both shapes can be given to a Phoenix `<.input type="select">` or to
`Phoenix.HTML.Form.options_for_select/2`.

A dataset that does not exist is handled three ways, depending on what suits the caller:

```elixir
iex> RefData.get("missing")
nil

iex> RefData.fetch("missing")
:error

iex> RefData.list_all_keys()
["countries", "countries_by_region", "payment_terms", "plans", "titles"]
```

`RefData.get!("missing")` raises `KeyError`. Use it in templates, where a misspelt
dataset name is a bug you want to hear about.

### Retiring an option

Suppose the Legacy plan is no longer sold, but existing customers are still on it.

Stored in `plans.json`:

```json
{"plans": [
  {"key": "Starter", "value": "starter"},
  {"key": "Pro", "value": "pro"},
  {"key": "Legacy", "value": "legacy"}
]}
```

Pass the plan's label in `:disabled` to grey it out in the form:

```elixir
iex> RefData.get("plans", disabled: ["Legacy"])
[
  [key: "Starter", value: "starter"],
  [key: "Pro", value: "pro"],
  [key: "Legacy", value: "legacy", disabled: true]
]
```

A browser will not submit a disabled option, but a crafted request can. Pass the
same list when validating so the stored value `"legacy"` is rejected, while the
other plans stay valid:

```elixir
iex> RefData.validate_value("plans", "legacy", disabled: ["Legacy"])
{:error, :disabled_value}

iex> RefData.validate_value("plans", "pro", disabled: ["Legacy"])
{:ok, "pro"}
```

Existing customers still see the right name, because labels ignore `:disabled`:

```elixir
iex> RefData.label("plans", "legacy")
"Legacy"
```

`:disabled` applies only to the call it is passed to. It does not change the stored
dataset, so you can decide per form or per user what to disable.

### Validating submissions

`validate_value/3` checks a submitted value against a dataset's **values** and
returns the value to store.

Stored in `payment_terms.json`, where the values are numbers:

```json
{"payment_terms": [
  {"key": "Net 7", "value": 7},
  {"key": "Net 30", "value": 30},
  {"key": "Net 60", "value": 60}
]}
```

Browsers submit everything as strings, so a string is matched against each value's
text form and the stored number comes back:

```elixir
iex> RefData.validate_value("payment_terms", "30")
{:ok, 30}
```

`45` is not one of the stored values, and `"Net 30"` is a label rather than a value:

```elixir
iex> RefData.validate_value("payment_terms", "45")
{:error, :invalid_value}

iex> RefData.validate_value("payment_terms", "Net 30")
{:error, :invalid_value}
```

Values inside groups are found. `countries_by_region.json`, shown above, stores
`"NZ"` under Oceania:

```elixir
iex> RefData.validate_value("countries_by_region", "NZ")
{:ok, "NZ"}

iex> RefData.validate_value("countries_by_region", "Oceania")
{:error, :invalid_value}
```

In a controller or LiveView, use the returned value rather than the raw parameter:

```elixir
case RefData.validate_value("payment_terms", params["payment_terms"]) do
  {:ok, days} -> Invoices.create(customer, due_in_days: days)
  {:error, _reason} -> {:error, "Choose a payment term from the list"}
end
```

When you only need yes or no, as in the changeset in the quick start, use
`valid_value?/3`. For a multi-select field, check each submitted value. The
`countries` dataset stores `"AU"`, `"CA"` and `"NZ"`, so only `"XX"` is rejected:

```elixir
iex> submitted = ["AU", "NZ", "XX"]
iex> Enum.reject(submitted, &RefData.valid_value?("countries", &1))
["XX"]
```

The possible errors are:

| Error | Meaning |
| --- | --- |
| `:unknown_dataset` | No dataset has that name. |
| `:invalid_value` | No option has that value. |
| `:disabled_value` | Every option with that value is in `:disabled`. |
| `:ambiguous_value` | A string matches two different values, such as `30` and `"30"` in one dataset. Avoid mixing them. |

Matching is exact. `"30"` matches the number `30`, but `"030"`, `"30.0"` and `" 30"`
do not. A number or boolean passed from Elixir must match the stored type, and `nil`,
lists and maps are never valid. If two labels share a value, the value is valid while
either label is enabled.

### Displaying stored values

`label/3` turns a stored value back into its label.

Stored in `payment_terms.json`:

```json
{"payment_terms": [
  {"key": "Net 7", "value": 7},
  {"key": "Net 30", "value": 30},
  {"key": "Net 60", "value": 60}
]}
```

A customer record holds the number `30`, or the string `"30"` if it came straight
from a form. Both find the label, and `45` is not stored so it has none:

```elixir
iex> RefData.label("payment_terms", 30)
"Net 30"

iex> RefData.label("payment_terms", "30")
"Net 30"

iex> RefData.label("payment_terms", 45)
nil
```

Groups are searched too. `countries_by_region.json` stores `"CA"` with the label
`"Canada"` under Americas:

```elixir
iex> RefData.label("countries_by_region", "CA")
"Canada"
```

It returns `nil` for an unknown dataset or value, so a template can supply a fallback:
`RefData.label("plans", @customer.plan) || "Unknown plan"`. If several labels share a
value, the first one is returned.

### A module for your application

`use RefData` defines the same functions on a module of your own. It gives the rest
of your code one place to call, and one place to change if you later move the data
to a server you supervise yourself:

```elixir
defmodule MyApp.RefData do
  use RefData
end

MyApp.RefData.get("titles")
MyApp.RefData.valid_value?("countries", "CA")
MyApp.RefData.label("countries", "CA")
```

## Advanced

Most applications need nothing in this section.

### File locations and releases

Keep datasets under your application's `priv/` directory. Mix bundles `priv/` into
releases, and `Application.app_dir/2` finds it wherever the release is installed,
which is why the path is set in `config/runtime.exs`. A relative path such as
`"priv/ref_data"` works in development but depends on the directory the release is
started from.

An empty directory is valid. A missing directory or an invalid file stops your
application from starting, with an error that names the path. If no `:path` is
configured, RefData starts nothing, and lookups exit with `:noproc` until you
configure one or name a source yourself.

Treat datasets as trusted input. Files are read whole, with no size limits, so point
RefData only at directories your application controls and never at uploaded files.

### Separate sets of data

To keep independent sets of datasets, for example one per context, start an instance
for each in your supervision tree and leave `:path` unconfigured:

```elixir
children = [
  {RefData, name: MyApp.Billing.RefData, path: Application.app_dir(:my_app, "priv/billing")},
  {RefData, name: MyApp.Shipping.RefData, path: Application.app_dir(:my_app, "priv/shipping")}
]
```

Select one with `:server`, or bind a module to it so callers do not repeat the name:

```elixir
RefData.get("payment_terms", server: MyApp.Billing.RefData)

defmodule MyApp.Billing.Options do
  use RefData, server: MyApp.Billing.RefData
end

MyApp.Billing.Options.get("payment_terms")
```

Pass `name: nil` to start an unnamed instance and query it by PID.

### Scripts, jobs and tests

`RefData.load/1` reads a directory into a catalog, a plain value you hold yourself.
Nothing needs to be configured or started. This import script validates a CSV of
customers before inserting them:

```elixir
{:ok, catalog} = RefData.load("priv/ref_data")

for line <- File.stream!("customers.csv") |> Enum.drop(1) do
  [name, country] = line |> String.trim() |> String.split(",")

  case RefData.validate_value("countries", country, source: catalog) do
    {:ok, code} -> IO.puts("importing #{name} (#{RefData.label("countries", code, source: catalog)})")
    {:error, reason} -> IO.puts("skipping #{name}: #{reason}")
  end
end
```

Every lookup, label and validation function accepts `source: catalog`. A catalog is
a snapshot: it does not change if the files do, and loading one does not affect the
shared storage. Call `RefData.load/1` again for fresh data. It returns
`{:error, reason}` for a missing directory or an invalid file.

In tests, a catalog loaded from a fixture directory lets you exercise a function
without starting anything.

### How storage works

| | Shared storage | Catalog |
| --- | --- | --- |
| Started by | Configuring `:path`, or adding `{RefData, ...}` to a supervision tree | Calling `RefData.load/1` |
| Data lives in | An ETS table readable by every process on the node | A value held by the caller |
| Selected with | Nothing for the default, or `server: name` | `source: catalog` |
| Reload changed files | Restart the instance | Load a new catalog |

- A supervised process owns each table. It loads every file before making the table
  visible, and if it crashes its supervisor restarts it and reloads the files.
- Lookups read the table directly from the calling process. They do not send a
  message to the owner, so reads do not queue behind each other.
- The table is protected: only the owner can write to it.
- A lookup made while the owner is starting or stopping exits with `:noproc`. That is
  different from a missing dataset, which returns `nil` or `:error`.
- A server on another node is queried by message, because ETS tables are local.
- `:source` also accepts a server name. Supplying both `:source` and `:server` raises
  `ArgumentError`.

## Migrating from 0.2

- Upgrade Elixir to 1.18 or later. Jason is no longer a runtime dependency.
- The default server no longer assumes a `ref_data/` directory. Set
  `config :ref_data, path: "ref_data"` to keep the old location, or better, move the
  files to `priv/ref_data` as shown above.
- `use RefData` and successful flat lookups continue to work.
- Grouped results now use string-labelled tuples: `{"Oceania", options}` rather
  than nested atom-keyed keyword lists. Update any code inspecting groups directly.
- Missing keys return `nil` from `get` or `:error` from `fetch`. Use `get!` to raise.
- Duplicate names and malformed definitions fail startup with a file-specific error.
- Replace `use Mix.Config` with `import Config`.
- The old callback declarations were removed; RefData is a concrete API rather
  than a behaviour. Internal server state and loader return values have changed.

## Development

Install the versions in `.tool-versions` (Elixir 1.20.5 and OTP 29.1.2), then run:

```sh
mix deps.get
mix format --check-formatted
mix compile --warnings-as-errors
mix test --warnings-as-errors
mix credo --strict
mix hex.audit
mix docs --warnings-as-errors
mix hex.build
```

CI tests Elixir 1.18, 1.19 and 1.20 across OTP 27 to 29. The documented examples run
against the datasets in `test/fixtures/docs`.
