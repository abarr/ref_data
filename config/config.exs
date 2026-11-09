import Config

if config_env() == :test do
  config :ref_data, start_default_server: false
end
