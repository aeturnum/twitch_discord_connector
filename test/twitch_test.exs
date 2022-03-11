defmodule TwitchDiscordConnectorTest.Twitch do
  use ExUnit.Case

  test "thumbnail convert" do
    "https://static-cdn.jtvnw.net/previews-ttv/live_user_attndotcom-{width}x{height}.jpg"
    |> TwitchDiscordConnector.Twitch.Helpers.thumbnail({640, 360})
  end

  test "name gen" do
    name = TwitchDiscordConnector.Discord.image_name("test")
    assert String.contains?(name, "test")
    assert String.contains?(name, ".jpg")
  end

  test "user info" do
    {:ok, user} = TwitchDiscordConnector.Twitch.User.info_id(503_254)

    assert user["id"] == "503254"
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

    TwitchDiscordConnector.JsonDB.TwitchUserDB.save_user(
      %TwitchDiscordConnector.JsonDB.TwitchUserDB{
        uid: "503254",
        sub: %{
          "user_id" => "503254",
          "secret" => "wR8FRvoKebeV",
          "expires" => "2020-10-19T16:58:38.400707Z"
        }
      }
    )

    # assert TwitchDiscordConnector.Twitch.Subs.sig_valid?(503_254, headers, parsed_body) == true
  end

  test "poison?" do
    assert "{\"test\":true}" == %{"test" => true} |> Poison.encode!()
  end
end
