defmodule TwitchDiscordConnectorTest.Util do
  use ExUnit.Case

  alias TwitchDiscordConnector.Util.L

  test "log insp" do
    L.ins(%{"test" => "item"}, label: "test label")
  end
end
