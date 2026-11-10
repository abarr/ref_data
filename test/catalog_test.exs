defmodule RefData.CatalogTest do
  use ExUnit.Case, async: true

  # Defined here rather than shared with another test file, whose load order is not guaranteed.
  defmodule Wrapper do
    use RefData, server: RefData.CatalogTest.Server
  end

  @moduletag :tmp_dir

  test "a standalone snapshot supports lookup and validation without a dataset server", %{
    tmp_dir: dir
  } do
    File.write!(Path.join(dir, "data.json"), JSON.encode!(%{"example" => ["One", "Two"]}))
    assert {:ok, catalog} = RefData.load(dir)
    assert RefData.list_all_keys(catalog) == ["example"]

    assert RefData.get!("example", source: catalog) ==
             [[key: "One", value: "One"], [key: "Two", value: "Two"]]

    assert RefData.fetch("missing", source: catalog) == :error
    assert RefData.get("missing", source: catalog) == nil
    assert_raise KeyError, fn -> RefData.get!("missing", source: catalog) end
    assert RefData.validate_value("example", "Two", source: catalog) == {:ok, "Two"}

    File.write!(Path.join(dir, "data.json"), JSON.encode!(%{"replacement" => []}))
    assert RefData.list_all_keys(catalog) == ["example"]
    assert {:ok, replacement} = RefData.load(dir)
    assert RefData.list_all_keys(replacement) == ["replacement"]
  end

  test "standalone loading reports file errors", %{tmp_dir: dir} do
    File.write!(Path.join(dir, "bad.json"), "{")
    assert {:error, reason} = RefData.load(dir)
    assert reason =~ "bad.json"
  end

  test "source selection is explicit and wrapper defaults can be overridden", %{tmp_dir: dir} do
    File.write!(Path.join(dir, "data.json"), JSON.encode!(%{"example" => ["One"]}))
    {:ok, catalog} = RefData.load(dir)
    assert Wrapper.get("example", source: catalog) == [[key: "One", value: "One"]]
    assert Wrapper.validate_value("example", "One", source: catalog) == {:ok, "One"}
    assert Wrapper.valid_value?("example", "One", source: catalog)

    for fun <- [
          fn -> RefData.fetch("example", source: catalog, server: self()) end,
          fn -> RefData.validate_value("example", "One", source: catalog, server: self()) end
        ] do
      assert_raise ArgumentError, ~r/either :source or :server/, fun
    end
  end
end
