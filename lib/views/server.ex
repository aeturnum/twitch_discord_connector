defmodule TwitchDiscordConnector.Views.Server do


  def start_link do
    IO.puts("Starting https server!")
    Plug.Cowboy.https(TwitchDiscordConnector.Views.Router, [],
      port: 443,
      cipher_suite: :strong,
      certfile: "/etc/letsencrypt/live/twitch.naturecultur.es/cert.pem",
      keyfile: "/etc/letsencrypt/live/twitch.naturecultur.es/privkey.pem",
      cacertfile: "/etc/letsencrypt/live/twitch.naturecultur.es/chain.pem"
    )
  end
end
