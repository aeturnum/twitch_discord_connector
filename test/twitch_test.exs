defmodule TwitchDiscordConnectorTest.Twitch do
  use ExUnit.Case

  test "thumbnail convert" do
    "https://static-cdn.jtvnw.net/previews-ttv/live_user_attndotcom-{width}x{height}.jpg"
    |> TwitchDiscordConnector.Twitch.Helpers.thumbnail({640, 360})
  end

  test "name gen" do
    TwitchDiscordConnector.Discord.image_name("test") |> IO.inspect()
  end

  test "rehost" do
    # "https://static-cdn.jtvnw.net/previews-ttv/live_user_attndotcom-{width}x{height}.jpg"
    # |> TwitchDiscordConnector.Twitch.Helpers.thumbnail({640, 360})
    # |> TwitchDiscordConnector.Discord.rehost_jpg("test_account")
  end

  test "signature" do
    headers = [
      {"accept-encoding", "gzip"},
      {"connection", "close"},
      {"content-length", "11"},
      {"content-type", "application/json; charset=utf-8"},
      {"host", "twitch.naturecultur.es"},
      {"link",
       "<https://api.twitch.tv/helix/webhooks/hub>; rel=\"hub\", <https://api.twitch.tv/helix/streams?user_id=503254>; rel=\"self\""},
      {"twitch-notification-id", "0dbbbda0-3c05-4aa0-aed1-c98fa6d9807e"},
      {"twitch-notification-retry", "0"},
      {"twitch-notification-timestamp", "2020-10-19T16:59:03Z"},
      {"user-agent", "Go-http-client/1.1"},
      {"x-hub-signature",
       "sha256=8257877fcf26869e76e7e6591fdb41203699e5527c09ac1cd5fdc1aa6868e626"}
    ]

    parsed_body = %{"data" => []}

    TwitchDiscordConnector.JsonDB.TwitchDB.save_user(%TwitchDiscordConnector.JsonDB.TwitchDB{
      uid: "503254",
      sub: %{
        "user_id" => "503254",
        "secret" => "wR8FRvoKebeV",
        "expires" => "2020-10-19T16:58:38.400707Z"
      }
    })

    # TwitchDiscordConnector.JsonDB.TwitchDB.set("subs", sub_info)
    # TwitchDiscordConnector.JsonDB.TwitchDB.save_user()

    assert TwitchDiscordConnector.Twitch.Subs.sig_valid?(503_254, headers, parsed_body) == true
  end

  test "poison?" do
    %{"test" => true} |> Poison.encode!() |> IO.inspect()
  end
end
