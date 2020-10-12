# RefData

RefData is a library for Phoenix projects that lets you provide reference data 
for your forms (e.g. Gender) without using a database table. It has been written 
as tool for POC development but can be used in PROD for fields that are common 
for all Users and do not form part of complex queries.

You can use this link to see a demo.


## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `ref_data` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ref_data, "~> 0.1.0"}
  ]
end
```

## Using RefData

The data is defined as 'json' objects using a key and a list of values.

```json
{
    "gender": [
        "Male",
        "Female",
        "Non-binary"
    ]
}
```




Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/ref_data](https://hexdocs.pm/ref_data).

