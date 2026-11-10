defmodule RefData.DocTest do
  # Runs every `iex>` example in the function docs and the README against the
  # datasets those documents describe. It starts the default server, so it must
  # not run alongside other tests that use that name.
  use ExUnit.Case, async: false

  setup do
    start_supervised!({RefData, path: "test/fixtures/docs"})
    :ok
  end

  doctest RefData
  doctest_file("README.md")
end
