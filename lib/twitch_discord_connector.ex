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
      {TwitchDiscordConnector.JsonDB, [path: "testing.json", wipe: true]},
      {TwitchDiscordConnector.Event, []}
    ]
  end

  defp children(_) do
    # Task.start(fn ->
    #   :timer.sleep(100)
    #   IO.inspect(TwitchDiscordConnector.Discord.id_hook?(35_634_557), label: "hook?")
    #   IO.inspect(TwitchDiscordConnector.Discord.id_hook(35_634_557), label: "hook?")
    # end)

    [
      {TwitchDiscordConnector.JsonDB, [path: "db.json"]},
      {TwitchDiscordConnector.Event,
       [
         {TwitchDiscordConnector.Event.TwitchUser, 35_634_557},
         {TwitchDiscordConnector.Event.TwitchUser, 503_254}
       ]},
      {
        Plug.Cowboy,
        scheme: :https,
        plug: TwitchDiscordConnector.Views.Router,
        options: [
          port: 443,
          certfile: "/etc/letsencrypt/live/twitch.naturecultur.es/cert.pem",
          keyfile: "/etc/letsencrypt/live/twitch.naturecultur.es/privkey.pem",
          cacertfile: "/etc/letsencrypt/live/twitch.naturecultur.es/chain.pem"
        ]
      }
    ]
  end
end
