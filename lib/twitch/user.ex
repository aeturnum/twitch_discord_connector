defmodule TwitchDiscordConnector.Twitch.User do
  alias TwitchDiscordConnector.Twitch.Common

  def info_id(id), do: do_info(%{"id" => id})
  def info_name(username), do: do_info(%{"login" => username})

  defp do_info(params) do
    # http -v GET https://api.twitch.tv/helix/users login==aeturnum
    Common.get(%{
      url: "https://api.twitch.tv/helix/users",
      params: params,
      headers: TwitchDiscordConnector.Twitch.Auth.auth()
    })
    |> case do
      # single user
      {:ok, 200, %{"data" => [user]}} ->
        {:ok, user}

      # o h n o
      other ->
        IO.puts("Failed to fetch user(#{params}) info for some reason: #{inspect(other)}")
    end
  end

  def game_info(%{"game_id" => id}), do: game_info(id)

  def game_info(id) do
    Common.get(%{
      url: "https://api.twitch.tv/helix/games",
      params: %{"id" => id},
      headers: TwitchDiscordConnector.Twitch.Auth.auth()
    })
    |> case do
      # single user
      {:ok, 200, %{"data" => [game]}} ->
        {:ok, game}

      # o h n o
      other ->
        IO.puts("Failed to fetch game(#{id}) info for some reason: #{inspect(other)}")
    end
  end

  def streams_id(id), do: do_streams(%{"user_id" => id})
  def streams_login(login), do: do_streams(%{"user_login" => login})

  defp do_streams(params) do
    Common.get(%{
      url: "https://api.twitch.tv/helix/streams",
      params: params,
      headers: TwitchDiscordConnector.Twitch.Auth.auth()
    })
    |> case do
      # single stream
      {:ok, 200, %{"data" => [stream]}} ->
        {:ok, stream}

      # multiple streams?!
      {:ok, 200, %{"data" => streams}} ->
        {:ok, Enum.take(streams, 1)}

      # o h n o
      other ->
        IO.puts("Failed to fetch stream (#{params}) info for some reason: #{inspect(other)}")
    end
  end

  def subs() do
    Common.get(%{
      url: "https://api.twitch.tv/helix/webhooks/subscriptions",
      params: %{first: 20},
      headers: TwitchDiscordConnector.Twitch.Auth.auth()
    })
  end
end
