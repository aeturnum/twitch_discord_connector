import Config

config :twitch_discord_connector, :init_jsondb,
  path: "testing.json",
  wipe: true,
  image: "test_image_db.json"

config :blur, :client_key_source, :opts

config :twitch_discord_connector, :init_bot, [
  twitch_client_key: "oauth:v7ks8eonipmsq0xy58h7caeyhlxvki",
  name: "p0ryb0t",
  channels: []
]
