defmodule TwitchDiscordConnector.Startup do
  alias TwitchDiscordConnector.Startup
  alias TwitchDiscordConnector.Template.Src
  alias TwitchDiscordConnector.Util.L
  alias TwitchDiscordConnector.Template.SrcServer

  def build(), do: Application.get_env(:twitch_discord_connector, :environment)

  def startup_tasks() do
    L.i("Begining startup tasks for #{inspect(build())}")

    load_sources()

    L.i("Startup tasks complete")
  end

  # todo: figure out why this can't be a module variable
  def load_sources do
    L.i("Registering Sources...")

    Startup.__info__(:functions)
    |> Enum.reduce(
      [],
      fn {atom, arity}, src_list ->
        case Atom.to_string(atom) do
          "src_" <> _ -> [Function.capture(Startup, atom, arity) | src_list]
          _ -> src_list
        end
      end
    )
    |> Enum.each(fn src_maker -> SrcServer.register(src_maker.()) end)

    L.i("Sources registered")
  end

  # Source creators
  # All functions with the src_ prefix are expected to return a Src and will
  # be loaded on startup

  def src_twitch_user() do
    Src.new(
      "twitch.user",
      "Retrieve the information for a twitch user based on their username",
      %{
        "broadcaster_type" => "affiliate",
        "description" => "Pokemon GO Battler and Coach.",
        "display_name" => "th3six4ninja",
        "id" => "35634557",
        "login" => "th3six4ninja",
        "offline_image_url" => "",
        "profile_image_url" =>
          "https://static-cdn.jtvnw.net/jtv_user_pictures/a82d145d-f78d-43ea-ae54-8c4c46441bd3-profile_image-300x300.png",
        "type" => "",
        "view_count" => 10754
      },
      &TwitchDiscordConnector.Twitch.User.info_name/1
    )
  end

  def src_twitch_game() do
    Src.new(
      "twitch.game",
      "Retrieve the information for a game on twitch using the game's ID",
      %{
        "box_art_url" =>
          "https://static-cdn.jtvnw.net/ttv-boxart/Pok%C3%A9mon%20GO-{width}x{height}.jpg",
        "id" => "490655",
        "name" => "Pokémon GO"
      },
      &TwitchDiscordConnector.Twitch.User.game_info/1
    )
  end

  def src_twitch_stream() do
    Src.new(
      "twitch.stream",
      "Retrieve the information for a twitch stream based on the username of the streamer",
      %{
        "game_id" => "490655",
        "id" => "40345609102",
        "language" => "en",
        "started_at" => "2020-11-04T20:00:20Z",
        "tag_ids" => [
          "6ea6bca4-4712-4ab9-a906-e3336a9d8039",
          "1eba3cfe-51cc-460a-8259-bc8bb987f904",
          "e1a43486-eee5-4f36-9ee6-76e72af00180"
        ],
        "thumbnail_url" =>
          "https://static-cdn.jtvnw.net/previews-ttv/live_user_th3six4ninja-{width}x{height}.jpg",
        "title" =>
          "ChidorichuXD enters the DOJO! Join us for GBL, discussion, chill vibes, and cats!",
        "type" => "live",
        "user_id" => "35634557",
        "user_name" => "th3six4ninja",
        "viewer_count" => 7
      },
      &TwitchDiscordConnector.Twitch.User.streams_login/1
    )
  end

  def src_twitch_channel_url() do
    Src.new(
      "twitch.channel.url",
      "Format a twitch url given a streamers' account name",
      "https://www.twitch.tv/th3six4ninja",
      &TwitchDiscordConnector.Discord.channel/1
    )
  end

  def src_twitch_stream_time() do
    Src.new(
      "twitch.stream.time",
      "Nicely format the timestamp when a stream started",
      "2/19/2021, 19:58:43",
      &TwitchDiscordConnector.Discord.format_time_from_str/1
    )
  end

  def src_twitch_rehost_thumbnail() do
    Src.new(
      "twitch.stream.thumbnail",
      "Rehost the current stream thumbnail in a unique URL. Used to avoid older announcements
      displaying the current stream thumbnail, as well as avoiding having the wrong thumbnail
      cached by a service provider. Requires S3-compatable creds on your account.

      Expects to be passed the results of 'twitch.user' and 'twitch.stream'.",
      "https://img.naturecultur.es/th3six4ninja_2_19_2021_Z4-Za.jpg",
      &TwitchDiscordConnector.Discord.get_stream_thumb/2
    )
  end
end
