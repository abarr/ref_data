defmodule RefDataTest do
  use ExUnit.Case, async: true

  defmodule Wrapper do
    use RefData, server: RefDataTest.WrappedServer
  end

  setup do
    server =
      start_supervised!({RefData.Server, path: Path.expand("../ref_data", __DIR__), name: nil})

    %{server: server}
  end

  test "lists all dataset names in alphabetical order", %{server: server} do
    assert RefData.list_all_keys(server) ==
             [
               "active",
               "countries",
               "countries_grouped",
               "countries_grouped_simple",
               "gender_simple"
             ]
  end

  test "loads simple and explicit options without coercing values", %{server: server} do
    assert RefData.get("active", server: server) ==
             [[key: "Enable", value: "true"], [key: "Disable", value: "false"]]

    assert RefData.get("countries", server: server) ==
             Enum.map(["Australia", "New Zealand", "Canada"], &[key: &1, value: &1])
  end

  test "both group formats produce string-labelled tuples", %{server: server} do
    expected = [
      {"Asia",
       [[key: "Australia", value: "Australia"], [key: "New Zealand", value: "New Zealand"]]},
      {"Americas", [[key: "Canada", value: "Canada"], [key: "USA", value: "USA"]]}
    ]

    assert RefData.get("countries_grouped", server: server) == expected
    assert RefData.get("countries_grouped_simple", server: server) == expected
  end

  test "missing keys do not terminate the server", %{server: server} do
    assert RefData.fetch("missing", server: server) == :error
    assert RefData.get("missing", server: server) == nil
    assert_raise KeyError, fn -> RefData.get!("missing", server: server) end
    assert RefData.get!("active", server: server) != []
    assert Process.alive?(server)
  end

  test "disabling flat and grouped labels leaves stored options unchanged", %{server: server} do
    assert [_, [key: "Female", value: "Female", disabled: true], _] =
             RefData.get("gender_simple", server: server, disabled: ["Female"])

    assert [{"Asia", [[key: "Australia", value: "Australia", disabled: true], _]}, _] =
             RefData.get("countries_grouped", server: server, disabled: ["Australia"])

    assert [_, [key: "Female", value: "Female"], _] =
             RefData.get("gender_simple", server: server)
  end

  test "disabled matches option labels rather than submitted values", %{server: server} do
    assert [[key: "Enable", value: "true", disabled: true], _] =
             RefData.get("active", server: server, disabled: ["Enable"])

    assert [[key: "Enable", value: "true"], _] =
             RefData.get("active", server: server, disabled: ["true"])
  end

  test "disabling options recurses through nested and empty groups" do
    options = [{"Outer", [{"Inner", [[key: "Label", value: "code"]]}, {"Empty", []}]}]

    assert RefData.disable_options(options, ["Label"]) ==
             [
               {"Outer",
                [{"Inner", [[key: "Label", value: "code", disabled: true]]}, {"Empty", []}]}
             ]
  end

  test "invalid query options raise in the caller", %{server: server} do
    for opts <- [[disabled: nil], [disabled: [1]], [unknown: true]] do
      assert_raise ArgumentError, fn -> RefData.get("active", [server: server] ++ opts) end
    end

    assert Process.alive?(server)
  end

  test "wrapper functions delegate to a configured server" do
    start_supervised!(
      {RefData.Server,
       path: Path.expand("../ref_data", __DIR__), name: RefDataTest.WrappedServer},
      id: :wrapper
    )

    assert "active" in Wrapper.list_all_keys()
    assert {:ok, data} = Wrapper.fetch("active")
    assert Wrapper.get("active") == data
    assert Wrapper.get!("active") == data
    assert Wrapper.validate_value("active", "true") == {:ok, "true"}
    assert Wrapper.valid_value?("active", "true")
    refute Wrapper.valid_value?("active", "Enable")
  end
end
