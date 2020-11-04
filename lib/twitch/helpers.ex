defmodule TwitchDiscordConnector.Twitch.Helpers do
  @moduledoc """
  Generic twitch helpers
  """

  @doc """
  Get a thumbnail url based on the kind of template that twitch provides through its api.any()

  Example: "https://static-cdn.jtvnw.net/previews-ttv/live_user_attndotcom-{width}x{height}.jpg", {640, 360} ->
    "https://static-cdn.jtvnw.net/previews-ttv/live_user_attndotcom-640x360.jpg"

  """
  def thumbnail(url_template, {width, height}) do
    rep_map = %{"{width}" => "#{inspect(width)}", "{height}" => "#{inspect(height)}"}
    String.replace(url_template, Map.keys(rep_map), fn s -> Map.get(rep_map, s, s) end)
  end
end
