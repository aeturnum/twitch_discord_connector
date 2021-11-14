defmodule TwitchDiscordConnector.Twitch.User do
  @moduledoc """
  Helpers to getting twitch user information

  Todo: create structs for these things
  """

  alias TwitchDiscordConnector.Twitch.Common

  def info_id(id), do: do_info(%{"id" => id})
  def info_name(username), do: do_info(%{"login" => username})

  # %{
  #   "broadcaster_type" => "affiliate",
  #   "description" => "Pokemon GO Battler and Coach.",
  #   "display_name" => "th3six4ninja",
  #   "id" => "35634557",
  #   "login" => "th3six4ninja",
  #   "offline_image_url" => "",
  #   "profile_image_url" => "https://static-cdn.jtvnw.net/jtv_user_pictures/a82d145d-f78d-43ea-ae54-8c4c46441bd3-profile_image-300x300.png",
  #   "type" => "",
  #   "view_count" => 10754
  # }
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
      {:error, _, real_error} ->
        IO.puts("Failed to fetch user(#{inspect(params)}) info for some reason: #{inspect(real_error)}")
        {:error, real_error}
      other ->
        IO.puts("Failed to fetch user(#{inspect(params)}) info for some reason: #{inspect(other)}")
        {:error, other}
    end
  end

  def game_info(%{"game_id" => id}), do: game_info(id)

  # %{
  #   "box_art_url" => "https://static-cdn.jtvnw.net/ttv-boxart/Pok%C3%A9mon%20GO-{width}x{height}.jpg",
  #   "id" => "490655",
  #   "name" => "Pokémon GO"
  # }
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
      {:error, _, real_error} ->
        IO.puts("Failed to fetch game(#{id}) info for some reason: #{inspect(real_error)}")
        {:error, real_error}
      other ->
        IO.puts("Failed to fetch game(#{id}) info for some reason: #{inspect(other)}")
        {:error, other}
    end
  end

  def streams_id(id), do: do_streams(%{"user_id" => id})
  def streams_login(login), do: do_streams(%{"user_login" => login})

  #  %{
  #    "game_id" => "490655",
  #    "id" => "40345609102",
  #    "language" => "en",
  #    "started_at" => "2020-11-04T20:00:20Z",
  #    "tag_ids" => ["6ea6bca4-4712-4ab9-a906-e3336a9d8039",
  #     "1eba3cfe-51cc-460a-8259-bc8bb987f904",
  #     "e1a43486-eee5-4f36-9ee6-76e72af00180"],
  #    "thumbnail_url" => "https://static-cdn.jtvnw.net/previews-ttv/live_user_th3six4ninja-{width}x{height}.jpg",
  #    "title" => "ChidorichuXD enters the DOJO! Join us for GBL, discussion, chill vibes, and cats!",
  #    "type" => "live",
  #    "user_id" => "35634557",
  #    "user_name" => "th3six4ninja",
  #    "viewer_count" => 7
  #  }

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
      {:error, _, real_error} ->
        IO.puts("Failed to fetch stream (#{inspect(params)}) info for some reason: #{inspect(real_error)}")
        {:error, real_error}
      other ->
        IO.puts("Failed to fetch stream (#{inspect(params)}) info for some reason: #{inspect(other)}")
        {:error, other}
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
