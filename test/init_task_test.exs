defmodule Mix.Tasks.RefData.InitTest do
  # Changes the working directory and the Mix shell, so it cannot run concurrently.
  use ExUnit.Case, async: false

  alias Mix.Tasks.RefData.Init

  @moduletag :tmp_dir

  setup do
    shell = Mix.shell()
    Mix.shell(Mix.Shell.Process)
    on_exit(fn -> Mix.shell(shell) end)
  end

  test "creates a loadable example dataset and prints the configuration", %{tmp_dir: dir} do
    File.cd!(dir, fn -> Init.run([]) end)

    assert {:ok, catalog} = RefData.load(Path.join(dir, "priv/ref_data"))
    assert RefData.list_all_keys(catalog) == ["example"]
    assert_received {:mix_shell, :info, ["Created priv/ref_data/example.json"]}
    assert_received {:mix_shell, :info, [config]}
    assert config =~ ~s|config :ref_data, path: Application.app_dir(:ref_data, "priv/ref_data")|
  end

  test "leaves existing datasets untouched", %{tmp_dir: dir} do
    target = Path.join(dir, "priv/ref_data")
    File.mkdir_p!(target)
    File.write!(Path.join(target, "mine.json"), ~s({"mine": ["A"]}))

    File.cd!(dir, fn -> Init.run([]) end)

    assert File.ls!(target) == ["mine.json"]
    assert_received {:mix_shell, :info, ["priv/ref_data already contains datasets" <> _]}
  end
end
