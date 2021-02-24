import Config

# client = session.client('s3',
#                         region_name='sfo2',
#                         endpoint_url='https://sfo2.digitaloceanspaces.com',
#                         aws_access_key_id=...,
#                         aws_secret_access_key=...)

config :twitch_discord_connector, :environment, Mix.env()

config :ex_aws, :s3,
  scheme: "https://",
  host: "sfo2.digitaloceanspaces.com",
  region: "sfo2"

config :logger, :console, format: {TwitchDiscordConnector.Util.L, :format}

import_config "#{config_env()}.exs"
