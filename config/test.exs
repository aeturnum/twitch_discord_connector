import Config

config :twitch_discord_connector, :init_jsondb,
  path: "testing.json",
  wipe: true,
  image: "test_image_db.json"
