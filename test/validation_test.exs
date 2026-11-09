defmodule RefData.ValidationTest do
  use ExUnit.Case, async: true

  @moduletag :tmp_dir

  setup %{tmp_dir: dir} do
    datasets = %{
      "status" => [
        %{"key" => "Enabled", "value" => true},
        %{"key" => "Disabled", "value" => false}
      ],
      "counts" => [%{"key" => "One", "value" => 1}, %{"key" => "Fraction", "value" => 1.5}],
      "countries" => [%{"Region" => [%{"Nested" => [%{"key" => "Australia", "value" => "AU"}]}]}],
      "ambiguous" => [
        %{"key" => "Boolean", "value" => true},
        %{"key" => "String", "value" => "true"}
      ],
      "duplicates" => [%{"key" => "First", "value" => "A"}, %{"key" => "Second", "value" => "A"}],
      "empty" => []
    }

    for {key, values} <- datasets do
      File.write!(Path.join(dir, "#{key}.json"), JSON.encode!(%{key => values}))
    end

    server = start_supervised!({RefData, path: dir, name: nil})
    {:ok, catalog} = RefData.load(dir)
    %{sources: [server: server, source: catalog]}
  end

  test "returns the label for a stored value", %{sources: sources} do
    for source <- sources do
      opts = [source]
      assert RefData.label("countries", "AU", opts) == "Australia"
      assert RefData.label("status", false, opts) == "Disabled"
      assert RefData.label("counts", "1", opts) == "One"
      assert RefData.label("ambiguous", "true", opts) == "String"
      assert RefData.label("ambiguous", true, opts) == "Boolean"
      assert RefData.label("duplicates", "A", opts) == "First"
      assert RefData.label("countries", "Australia", opts) == nil
      assert RefData.label("missing", "AU", opts) == nil
      assert RefData.label("empty", nil, opts) == nil
      assert_raise ArgumentError, fn -> RefData.label("status", true, opts ++ [disabled: []]) end
    end
  end

  test "validates submitted values rather than labels through nested groups", %{sources: sources} do
    for source <- sources do
      opts = [source]
      assert RefData.validate_value("countries", "AU", opts) == {:ok, "AU"}
      assert RefData.valid_value?("countries", "AU", opts)
      assert RefData.validate_value("countries", "Australia", opts) == {:error, :invalid_value}
      refute RefData.valid_value?("countries", "Australia", opts)
    end
  end

  test "canonicalizes browser strings only when they represent known values", %{sources: sources} do
    for source <- sources do
      opts = [source]
      assert RefData.validate_value("status", "true", opts) == {:ok, true}
      assert RefData.validate_value("status", "false", opts) == {:ok, false}
      assert RefData.validate_value("status", false, opts) == {:ok, false}
      assert RefData.validate_value("counts", "1", opts) == {:ok, 1}
      assert RefData.validate_value("counts", "1.5", opts) == {:ok, 1.5}
      assert RefData.validate_value("counts", 1, opts) == {:ok, 1}
      assert RefData.validate_value("counts", 1.0, opts) == {:error, :invalid_value}

      for value <- ["01", "1.0", "1e0", " 1", "1 ", "2"] do
        assert RefData.validate_value("counts", value, opts) == {:error, :invalid_value}
      end
    end
  end

  test "rejects malformed values without coercion", %{sources: sources} do
    for source <- sources, value <- [nil, [], ["true"], %{}, {:value, true}, :true_value] do
      assert RefData.validate_value("status", value, [source]) == {:error, :invalid_value}
    end
  end

  test "distinguishes missing datasets, empty datasets and disabled choices", %{sources: sources} do
    for source <- sources do
      opts = [source]
      assert RefData.validate_value("missing", "x", opts) == {:error, :unknown_dataset}
      assert RefData.validate_value("empty", "x", opts) == {:error, :invalid_value}

      assert RefData.validate_value("countries", "AU", opts ++ [disabled: ["Australia"]]) ==
               {:error, :disabled_value}

      refute RefData.valid_value?("status", "true", opts ++ [disabled: ["Enabled"]])

      assert RefData.validate_value("status", "false", opts ++ [disabled: ["Enabled"]]) ==
               {:ok, false}

      assert RefData.validate_value("countries", "AU", opts) == {:ok, "AU"}
    end
  end

  test "fails closed on ambiguous browser representations", %{sources: sources} do
    for source <- sources do
      opts = [source]
      assert RefData.validate_value("ambiguous", "true", opts) == {:error, :ambiguous_value}
      refute RefData.valid_value?("ambiguous", "true", opts)
      assert RefData.validate_value("ambiguous", true, opts) == {:ok, true}

      assert RefData.validate_value("ambiguous", "true", opts ++ [disabled: ["Boolean"]]) ==
               {:ok, "true"}
    end
  end

  test "duplicate values remain valid if at least one matching option is enabled", %{
    sources: sources
  } do
    for source <- sources do
      opts = [source]
      assert RefData.validate_value("duplicates", "A", opts) == {:ok, "A"}

      assert RefData.validate_value("duplicates", "A", opts ++ [disabled: ["First"]]) ==
               {:ok, "A"}

      assert RefData.validate_value("duplicates", "A", opts ++ [disabled: ["First", "Second"]]) ==
               {:error, :disabled_value}
    end
  end
end
