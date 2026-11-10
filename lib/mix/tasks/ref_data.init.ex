defmodule Mix.Tasks.RefData.Init do
  @shortdoc "Creates priv/ref_data with an example dataset"

  @moduledoc """
  Creates `priv/ref_data/` in the current project and prints the configuration
  needed to load it.

      $ mix ref_data.init

  An example dataset is added only when the directory contains no JSON files.
  Existing files are never changed, so the task is safe to run again.
  """

  use Mix.Task

  @dir "priv/ref_data"
  @example ~s({"example": ["First option", "Second option"]}\n)

  @impl true
  def run(_args) do
    File.mkdir_p!(@dir)

    if Path.wildcard(Path.join(@dir, "*.json")) == [] do
      path = Path.join(@dir, "example.json")
      File.write!(path, @example)
      Mix.shell().info("Created #{path}")
    else
      Mix.shell().info("#{@dir} already contains datasets; nothing was changed")
    end

    Mix.shell().info("""

    Add this to config/runtime.exs to load the datasets at startup:

        config :ref_data, path: Application.app_dir(:#{Mix.Project.config()[:app]}, "#{@dir}")
    """)
  end
end
