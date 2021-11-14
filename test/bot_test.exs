defmodule TwitchDiscordConnectorTest.BotTest do
  use ExUnit.Case

  test "check that we do proper matching on friend codes" do
    lines = [
      {"This is a normal line of text", false},
      {"2000-2000-2000", true},
      {"2000:2000-2000", false},
      {"2000Redred: 2002-2006", false},
      {"2000.2000.2000", true},
      {"200020002000", true},
    ]

    for {line, should_match} <- lines do
      assert TwitchDiscordConnector.Twitch.Bot.match_line(line) == should_match
    end
  end

end
