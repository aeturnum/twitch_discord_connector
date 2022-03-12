import Config

config :blur, :client_key_source, :opts

config :twitch_discord_connector, :init_jsondb, path: "db.json"

config :twitch_discord_connector, :init_event, [{TwitchDiscordConnector.Event.Loader, {}}]
