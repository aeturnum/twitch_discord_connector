import Config

# use prod settings for dev
config :twitch_discord_connector, :init_jsondb, path: "db.json"

config :twitch_discord_connector, :init_event, [{TwitchDiscordConnector.Event.Loader, {}}]

config :blur, :client_key_source, :opts

config :twitch_discord_connector, :init_bot,
  name: "p0ryb0t",
  channels: ["#aeturnum"],
  twitch_client_key: "oauth:v7ks8eonipmsq0xy58h7caeyhlxvki"
