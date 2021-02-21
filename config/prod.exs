import Config

config :twitch_discord_connector, :init_jsondb, path: "db.json"

config :twitch_discord_connector, :init_event, [{TwitchDiscordConnector.Event.Loader, {}}]
