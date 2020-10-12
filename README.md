# RefData

RefData is a library for Phoenix projects that lets you provide reference data 
for your forms (e.g. Gender) without using a database table. It has been written 
as tool for POC development but can be used in PROD for fields that are common 
for all Users and do not form part of complex queries.

You can use this link to see a demo.


## Installation

The package can be installed by adding `ref_data` to your list of dependencies in 
`mix.exs`:

```elixir
def deps do
  [
    {:ref_data, "~> 0.1.0"}
  ]
end
```

## Config

`RefData` defaults to looking for `json` objects at teh `root` of teh project in a 
directory called `ref_data`. You can customise the path to your data by adding an entry
in your `config.exs` file.

```elixir
use Mix.Config

...

config :ref_data,
  path: "path_to_your_dir (e.g. data)"

...

```


## Defining Data

The data is defined as `json` objects using a key and a list of values.

```json
{
    "gender": [
        "Male",
        "Female",
        "Non-binary"
    ]
}
```

You can also define grouped data by creating a list of key value pairs of data.

```json
{
    "countries_grouped": 
    [
        { "Asia": ["Australia", "New Zealand"]},
        { "Americas": ["Canada", "USA"]}
    ]
}
```

## Using RefData

Assuming you `use RefData` in a module named `MyApp.MyRefData` your API is:


`MyRefData.list_all_keys/0`
It will list all keys for data held in memory

```
iex(1)> MyRefData.list_all_keys
["months", "gender"]
```


`MyRefData.get/1`
When given a key will return a list of data in format required by Phoenix.HTML.select

```
iex(1)> MyRefData.get("gender")
[
  [key: "Male", value: "male"],
  [key: "Female", value: "female"],
  [key: "Non-binary", value: "non-binary"]
]
```

`MyRefData.get/2`
        