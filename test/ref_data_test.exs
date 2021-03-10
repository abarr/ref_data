defmodule RefDataTest do
  use ExUnit.Case

  setup_all do
    {:ok, pid} = GenServer.start_link(RefData.Server, "./ref_data")
    {:ok, server: pid}
  end

  test "Get a list of all keys from RefData", %{server: server} do
    assert [
             "active",
             "countries",
             "countries_grouped",
             "countries_grouped_simple",
             "gender_simple"
           ] ==
             GenServer.call(server, {:get_all_keys})
  end

  test "Get the data when the definition groups values", %{server: server} do
    simple = GenServer.call(server, {"countries_grouped_simple"})
    defined = GenServer.call(server, {"countries_grouped"})

    assert [
             [
               Asia: [
                 [key: "Australia", value: "Australia"],
                 [key: "New Zealand", value: "New Zealand"]
               ]
             ],
             [
               Americas: [
                 [key: "Canada", value: "Canada"],
                 [key: "USA", value: "USA"]
               ]
             ]
           ] == simple

    assert [
             [
               Asia: [
                 [key: "Australia", value: "Australia"],
                 [key: "New Zealand", value: "New Zealand"]
               ]
             ],
             [
               Americas: [
                 [key: "Canada", value: "Canada"],
                 [key: "USA", value: "USA"]
               ]
             ]
           ] == defined
  end

  test "Get the data when the definition defines keys and values", %{server: server} do
    resp = GenServer.call(server, {"active"})

    assert [[key: "Enable", value: "true"], [key: "Disable", value: "false"]] == resp
  end

  test "Get the data when simple JSON is used - duplicate values for key and value", %{
    server: server
  } do
    resp = GenServer.call(server, {"countries"})

    assert [
             [key: "Australia", value: "Australia"],
             [key: "New Zealand", value: "New Zealand"],
             [key: "Canada", value: "Canada"]
           ] == resp
  end

  test "Get the data when simple JSON is used", %{server: server} do
    resp = GenServer.call(server, {"gender_simple"})

    assert [
             [key: "Male", value: "Male"],
             [key: "Female", value: "Female"],
             [key: "Non-binary", value: "Non-binary"]
           ] == resp
  end

  test "Get passing in a list of values to disable", %{server: server} do
    resp = GenServer.call(server, {"gender_simple", disabled: ["Female"]})

    assert [
             [key: "Male", value: "Male"],
             [key: "Female", value: "Female", disabled: true],
             [key: "Non-binary", value: "Non-binary"]
           ] == resp
  end
end
