# RefData  ![Elixir CI](https://github.com/abarr/ref_data/workflows/Elixir%20CI/badge.svg?branch=master)


RefData is a library for Phoenix projects that lets you provide reference data 
for your forms (e.g. Gender) without using a database table. It has been written 
as tool for POC development but can be used in PROD for fields that are common 
and do not form part of complex queries.

It's primary purpose is supporting the use of `Phoenix.HTML.select`.

The library is a supervised `GenServer` that starts as its own application when your 
applications starts. It will hold all of your defined reference data in memory for fast 
retrieval when needed. 

Version 0.2.0 is a breaking change see CHANGELOG

## Installation

The package can be installed by adding `ref_data` to your list of dependencies in 
`mix.exs`:

```elixir
def deps do
  [
    {:ref_data, "~> 0.2.0"}
  ]
end
```

## Config

`RefData` defaults to looking for `json` objects at the `root` of the project in a 
directory called `ref_data`. You can customise the path to your data by adding an entry
in your `config.exs` file.

```elixir
use Mix.Config

...

config :ref_data,
  path: "path/to/your/dir"

...

```

## Defining Data

RefData supports a number of different definitions. The simplest definitons are a `json` object 
that uses the type of reference data as the key and a list of values is generated as a list of key value pairs. 
`RefData` will convert the definitions into `Maps` e.g. 

```json
{ 
  "gender": [
    "Male", 
    "Female"
  ]
}
```
Is converted into a `map` and held in state by teh `GenServer`:

```elixir
%{ 
  name: "gender", 
  data: [
    [key: "Male", value: "Male"], 
    [key: "Female", value: "Female"]
  ]
}
```

`RefData` also supports more descriptive definitions so that you can assign your own key value pairs. E.g. if you 
wish to support keys with different values you can provide the details: 

```json
{ 
  "name": "active", 
  "data": [
    {"key": "Enable", "value": "true"}, 
    {"key": "Disable", "value": "false"}
  ]
}
```
This will be standardised as a `map` and stored in state:

```elixir
%{ 
  name: "active", 
  data: [
    [key: "Enable", value: true], 
    [key: "Disable", value: false]
  ]
}
```

You can also define grouped data by creating a list of key value pairs of data. This can be doen using 
teh simple `json` syntax:

```json
{
    "countries_grouped": 
    [
        { "Asia": ["Australia", "New Zealand"]},
        { "Americas": ["Canada", "USA"]}
    ]
}
```

```elixir
%{ 
  name: "countries_grouped", 
  data: [
    [ "Oceania": 
      [key: "Australia", value: "Australia"],
      [key: "New Zealand", value: "New Zealand"],
    ]
    [ "Amercias": 
      [key: "Canada", value: "Canada"],
      [key: "USA", value: "USA"],
    ]
  ]
}
```

Alternatively, you can use teh more detailed `json` definition to customise the values:

```json
{
    "name": "countries_grouped",
    "data": [
        { "Asia": [
            {"key":"Australia", "value": "Aussie"},
            {"key":"New Zealand", "value": "Kiwi"}]
        },
        { "Americas": [
            {"key":"Canada", "value": "Canuck"}, 
            {"key":"USA", "value": "Yank"}]
        }
    ]
}
```
It will produce the standard `map` using your custom values

```elixir
%{ 
  name: "countries_grouped", 
  data: [
    [ "Oceania": 
      [key: "Australia", value: "Aussie"],
      [key: "New Zealand", value: "Kiwi"],
    ]
    [ "Amercias": 
      [key: "Canada", value: "Canuck"],
      [key: "USA", value: "Yank"],
    ]
  ]
}
```

## Using RefData

Assuming you `use RefData` in a module named `MyApp.MyRefData`

```elixir
defmodule MyApp.MyRefData do
  use RefData

end
```

My future plans include integrating `GetText` and `CLDR` and the configuration for these features will 
be in this module. Below are some usage examples:

`MyRefData.list_all_keys/0` will list all keys for data held in memory

```elixir
iex(1)> MyRefData.list_all_keys
["months", "gender"]
```


`MyRefData.get/1` given a key it will return a list of data in the format required by `Phoenix.HTML.select`. If the 
`json` defines grouped data it will return the appropriate format.

```elixir
iex(1)> MyRefData.get("gender")
[
  [key: "Male", value: "Male"],
  [key: "Female", value: "Female"],
  [key: "Non-binary", value: "Non-binary"]
]
```

```elixir
iex(1)> MyRefData.get("countries")
[
  Asia: [
    [key: "Australia", value: "Australia"],
    [key: "New Zealand", value: "New Zealand"]
  ],
  Americas: [
    [key: "Canada", value: "Canada"], 
    [key: "USA", value: "Usa"]]
]
```

`MyRefData.get/2`
        
When given a key and a switch you are able to disable data by passing in a list of
values to disable.

```elixir
iex(1)> MyRefData.get("gender", disabled: ["Female"])
[
  [key: "Male", value: "Male"],
  [key: "Female", value: "Female", disabled: true],
  [key: "Non-binary", value: "Non-binary"]
]
```
