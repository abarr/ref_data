defmodule RefData.DataTest do
  use ExUnit.Case, async: true

  alias RefData.Data

  @tag :tmp_dir
  test "empty directories and empty datasets are valid", %{tmp_dir: dir} do
    assert Data.load(dir) == {:ok, %{}}
    File.write!(Path.join(dir, "empty.json"), JSON.encode!(%{"empty" => []}))
    assert Data.load(dir) == {:ok, %{"empty" => []}}
  end

  @tag :tmp_dir
  test "invalid JSON and schema errors identify the source file", %{tmp_dir: dir} do
    path = Path.join(dir, "invalid.json")

    for contents <- [
          "{",
          "null",
          "[]",
          "{}",
          ~s({"a": [], "b": []}),
          ~s({"name": "a", "data": null}),
          ~s({"a": [42]}),
          ~s({"a": [{"key": "A", "value": null}]}),
          ~s({"a": [{"group": null}]})
        ] do
      File.write!(path, contents)
      assert {:error, reason} = Data.load(dir)
      assert reason =~ path
    end
  end

  @tag :tmp_dir
  test "missing directories and unreadable files report errors", %{tmp_dir: dir} do
    assert {:error, _} = Data.load(Path.join(dir, "missing"))
    path = Path.join(dir, "directory.json")
    File.mkdir!(path)
    assert {:error, reason} = Data.load(dir)
    assert reason =~ path
  end

  @tag :tmp_dir
  test "duplicate names are rejected", %{tmp_dir: dir} do
    for file <- ["a.json", "b.json"] do
      File.write!(Path.join(dir, file), JSON.encode!(%{"duplicate" => []}))
    end

    assert {:error, reason} = Data.load(dir)
    assert reason =~ "b.json"
    assert reason =~ "duplicate"
  end

  @tag :tmp_dir
  test "nested groups preserve order, scalar values and empty groups", %{tmp_dir: dir} do
    data = %{
      "name" => "values",
      "data" => [
        %{
          "group" => [
            %{"nested" => [%{"key" => "On", "value" => true}, %{"key" => "Count", "value" => 2}]}
          ]
        },
        %{"empty" => []}
      ]
    }

    File.write!(Path.join(dir, "values.json"), JSON.encode!(data))

    assert {:ok,
            %{
              "values" => [
                {"group", [{"nested", [[key: "On", value: true], [key: "Count", value: 2]]}]},
                {"empty", []}
              ]
            }} = Data.load(dir)
  end

  @tag :tmp_dir
  test "group labels do not create atoms", %{tmp_dir: dir} do
    label = "ref_data_group_#{System.unique_integer([:positive])}"
    File.write!(Path.join(dir, "groups.json"), JSON.encode!(%{"groups" => [%{label => ["One"]}]}))

    assert_raise ArgumentError, fn -> String.to_existing_atom(label) end
    assert {:ok, %{"groups" => [{^label, _}]}} = Data.load(dir)
    assert_raise ArgumentError, fn -> String.to_existing_atom(label) end
  end

  @tag :tmp_dir
  test "separate instances hold independent datasets", %{tmp_dir: dir} do
    File.write!(Path.join(dir, "custom.json"), JSON.encode!(%{"custom" => ["One"]}))
    server = start_supervised!({RefData.Server, path: dir, name: nil})
    other_dir = Path.join(dir, "other")
    File.mkdir!(other_dir)
    File.write!(Path.join(other_dir, "other.json"), JSON.encode!(%{"other" => ["Two"]}))
    other = start_supervised!({RefData, path: other_dir, name: nil}, id: :other)
    assert RefData.get("custom", server: server) == [[key: "One", value: "One"]]
    assert RefData.get("custom", server: other) == nil
    assert RefData.get("other", server: server) == nil
    assert RefData.get("other", server: other) == [[key: "Two", value: "Two"]]
  end

  @tag :tmp_dir
  test "startup returns a descriptive error for invalid data", %{tmp_dir: dir} do
    Process.flag(:trap_exit, true)
    File.write!(Path.join(dir, "bad.json"), "{")

    assert {:error, {:invalid_reference_data, reason}} =
             RefData.Server.start_link(path: dir, name: nil)

    assert reason =~ "bad.json"
  end
end
