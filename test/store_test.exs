defmodule RefData.StoreTest do
  use ExUnit.Case, async: true

  @moduletag :tmp_dir

  setup %{tmp_dir: dir} do
    File.write!(Path.join(dir, "data.json"), JSON.encode!(%{"example" => ["One", "Two"]}))
    %{path: dir}
  end

  test "lookups and validation work while the owner cannot handle messages", %{path: path} do
    server = start_supervised!({RefData, path: path, name: nil})
    :ok = :sys.suspend(server)

    try do
      task =
        Task.async(fn ->
          assert RefData.list_all_keys(server) == ["example"]
          assert {:ok, _} = RefData.fetch("example", server: server)

          assert RefData.get("example", server: server, disabled: ["One"]) ==
                   [[key: "One", value: "One", disabled: true], [key: "Two", value: "Two"]]

          assert RefData.validate_value("example", "One", server: server) == {:ok, "One"}
          assert RefData.valid_value?("example", "Two", server: server)
        end)

      assert Task.await(task, 1000)
    after
      :sys.resume(server)
    end
  end

  test "the default lookup API still selects the default server", %{path: path} do
    start_supervised!({RefData, path: path})
    assert RefData.list_all_keys() == ["example"]
    assert RefData.get("example") == [[key: "One", value: "One"], [key: "Two", value: "Two"]]
    assert RefData.validate_value("example", "One") == {:ok, "One"}
    assert RefData.valid_value?("example", "Two")
  end

  test "readers cannot modify the protected table", %{path: path} do
    server = start_supervised!({RefData, path: path, name: nil})
    table = :sys.get_state(server)
    assert :ets.info(table, :owner) == server
    assert :ets.info(table, :protection) == :protected
    assert_raise ArgumentError, fn -> :ets.insert(table, {"example", []}) end
    assert RefData.get!("example", server: server) != []
  end

  test "many concurrent readers can access an instance", %{path: path} do
    server = start_supervised!({RefData, path: path, name: nil})

    results =
      1..100
      |> Task.async_stream(fn _ -> RefData.validate_value("example", "One", server: server) end,
        max_concurrency: 20
      )
      |> Enum.to_list()

    assert Enum.all?(results, &(&1 == {:ok, {:ok, "One"}}))
  end

  test "a stopped owner's table disappears and is not reported as a missing dataset", %{
    path: path
  } do
    server = start_supervised!({RefData, path: path, name: nil})
    table = :sys.get_state(server)
    stop_supervised!(RefData)
    assert :ets.info(table) == :undefined
    assert {:noproc, _} = catch_exit(RefData.fetch("example", server: server))
    assert {:noproc, _} = catch_exit(RefData.validate_value("example", "One", server: server))
  end

  test "reads by a registered name follow a restarted instance", %{path: path} do
    # A private Registry gives this test a unique name without generating atoms.
    registry = start_supervised!({Registry, keys: :unique, name: RefData.StoreTest.Names})
    assert Process.alive?(registry)
    name = {:via, Registry, {RefData.StoreTest.Names, make_ref()}}

    supervisor =
      start_supervised!(%{
        id: :storage_supervisor,
        start:
          {Supervisor, :start_link,
           [[{RefData, path: path, name: name}], [strategy: :one_for_one]]},
        type: :supervisor
      })

    [{^name, server, _, _}] = Supervisor.which_children(supervisor)
    old_table = :sys.get_state(server)
    assert RefData.valid_value?("example", "One", server: name)

    :ok = Supervisor.terminate_child(supervisor, name)
    File.write!(Path.join(path, "data.json"), JSON.encode!(%{"example" => ["New"]}))
    {:ok, replacement} = Supervisor.restart_child(supervisor, name)

    refute replacement == server
    assert :ets.info(old_table) == :undefined
    assert RefData.validate_value("example", "New", server: name) == {:ok, "New"}
    refute RefData.valid_value?("example", "One", server: name)
  end

  test "legacy server messages remain compatible", %{path: path} do
    server = start_supervised!({RefData, path: path, name: nil})
    assert GenServer.call(server, {:get_all_keys}) == ["example"]
    assert GenServer.call(server, {:fetch, "example"}) == RefData.fetch("example", server: server)
    assert GenServer.call(server, {"missing"}) == nil

    assert GenServer.call(server, {"example", disabled: ["One"]}) ==
             RefData.get("example", server: server, disabled: ["One"])
  end
end
