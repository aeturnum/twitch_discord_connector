defmodule TwitchDiscordConnector do
  use Application

  def init(:ok) do
  end

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    Supervisor.start_link(
      children(Application.get_env(:twitch_discord_connector, :environment)),
      strategy: :one_for_one,
      name: TwitchDiscordConnector.Supervisor
    )
  end

  defp children(:test) do
    [
      {TwitchDiscordConnector.JsonDB,
       [path: "testing.json", wipe: true, image: "test_image_db.json"]},
      {TwitchDiscordConnector.Event, []}
    ]
  end

  defp children(_) do
    [
      {TwitchDiscordConnector.JsonDB, [path: "db.json"]},
      {TwitchDiscordConnector.Event, [{TwitchDiscordConnector.Event.Loader, {}}]},
      {
        Plug.Cowboy,
        scheme: :http, plug: TwitchDiscordConnector.Views.Router, options: [port: 4000]
      }
    ]
  end
end
