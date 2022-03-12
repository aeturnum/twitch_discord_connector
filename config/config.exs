import Config

config :twitch_discord_connector, :environment, Mix.env()

config :ex_aws, :s3,
  scheme: "https://",
  host: "sfo2.digitaloceanspaces.com",
  region: "sfo2"

config :logger, :console, format: {TwitchDiscordConnector.Util.L, :format}

import_config "#{config_env()}.exs"
