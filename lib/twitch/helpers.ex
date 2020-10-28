defmodule TwitchDiscordConnector.Twitch.Helpers do
  # alias TwitchDiscordConnector.Twitch.Common

  def thumbnail(url_template, {width, height}) do
    rep_map = %{"{width}" => "#{inspect(width)}", "{height}" => "#{inspect(height)}"}
    String.replace(url_template, Map.keys(rep_map), fn s -> Map.get(rep_map, s, s) end)
  end
end
