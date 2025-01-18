import Config

config :esbuild, :version, "0.23.0"

import_config "#{config_env()}.exs"
