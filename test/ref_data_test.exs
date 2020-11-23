defmodule RefDataTest do
  use ExUnit.Case

  test "Get a list of all keys from RefData" do
    resp = RefData.Server.handle_call({:all_keys}, nil, :ref_data)
    assert {:reply, ["countries", "months", "countries_grouped", "gender"], :ref_data} == resp
  end

  test "Get the raw data for one of the data definitions" do
    resp = RefData.Server.handle_call({"gender", :raw}, nil, :ref_data)
    assert {:reply, [{"gender", ["Male", "Female", "Non-binary"]}], :ref_data} == resp
  end

  test "Get the data when eth definition groups values" do
    resp = RefData.Server.handle_call("countries_grouped", nil, :ref_data)

    assert {:reply,
            [
              Asia: [
                [key: "Australia", value: "Australia"],
                [key: "New Zealand", value: "New Zealand"]
              ],
              Americas: [[key: "Canada", value: "Canada"], [key: "USA", value: "USA"]]
            ], :ref_data} == resp
  end

  test "Get the raw data for one of the data definitions with disabled list" do
    resp = RefData.Server.handle_call({"gender", disabled: ["Male"]}, nil, :ref_data)

    assert {:reply,
            [
              [key: "Male", value: "Male", disabled: true],
              [key: "Female", value: "Female"],
              [key: "Non-binary", value: "Non-binary"]
            ], :ref_data} == resp
  end

  test "Get the raw data for one of the data definitions with disabled list - lower case" do
    resp = RefData.Server.handle_call({"gender", disabled: ["Female"]}, nil, :ref_data)

    assert {:reply,
            [
              [key: "Male", value: "Male"],
              [key: "Female", value: "Female", disabled: true],
              [key: "Non-binary", value: "Non-binary"]
            ], :ref_data} == resp
  end

  test "Get the response when invalid data is provided" do
    resp = RefData.Server.handle_call("", nil, nil)
    assert {:stop, "The Application was unable to load reference data", nil} == resp
  end
end
