defmodule TwitchDiscordConnector.Discord do
  alias TwitchDiscordConnector.Util.H
  alias TwitchDiscordConnector.Job.Manager
  alias TwitchDiscordConnector.Discord
  alias TwitchDiscordConnector.Twitch.Common
  alias TwitchDiscordConnector.Twitch.User
  alias TwitchDiscordConnector.JsonDB.TwitchDB
  alias TwitchDiscordConnector.Util.L

  # def start_job(user_id) do
  #   Manager.start(
  #     {:stream_notify, -1},
  #     {&Discord.webhook/1, [user_id]},
  #     # wait 3 minutes
  #     # todo: calculate the delta from when the stream started
  #     60 * 3 * 1000
  #   )
  # end

  def webhook(user_id) do
    # todo: check stream is still running lol
    {:ok, stream} = User.streams_id(user_id) |> L.ins(label: "stream")

    case stream do
      [] ->
        L.w("Stream stopped for user #{user_id}")

      _ ->
        {:ok, game_info} = User.game_info(stream) |> L.ins(label: "game")
        {:ok, user_info} = User.info_id(user_id) |> L.ins(label: "user")

        case id_hook?(user_id) do
          true ->
            Common.post(%{
              url: id_hook(user_id),
              body: stream_message(user_info, stream, game_info)
            })

          false ->
            stream_message(user_info, stream, game_info)
            |> Poison.encode!()
            |> L.ins(label: "Simulated Payload")
        end
    end
  end

  # stream_preview = streams['preview']['large']

  # channel_name = three_six_channel['name']

  def rehost_jpg(jpg_url, account_name) do
    name = image_name(account_name)

    Common.get(%{url: jpg_url})
    |> case do
      {:ok, _, image_binary} ->
        ExAws.S3.put_object(
          # bucket name
          "drex",
          # file name
          name,
          # actual image data
          image_binary,
          # acl
          acl: :public_read
        )
        |> ExAws.request!(get_aws_secrets())
        |> case do
          %{status_code: 200} -> {:ok, "#{get_aws_baseurl()}/#{name}"}
          other -> IO.puts("Upload failed: #{inspect(other)}")
        end

      other ->
        IO.puts("Rehosting failed: #{inspect(other)}")
    end
  end

  def image_name(channel) do
    day = H.now() |> DateTime.to_date()
    "#{channel}_#{day.month}_#{day.day}_#{day.year}_#{H.random_string(5)}.jpg"
  end

  #   {:ok,
  #  %{
  #    "game_id" => "490655",
  #    "id" => "40139934782",
  #    "language" => "en",
  #    "started_at" => "2020-10-18T22:54:53Z",
  #    "tag_ids" => ["6ea6bca4-4712-4ab9-a906-e3336a9d8039"],
  #    "thumbnail_url" => "https://static-cdn.jtvnw.net/previews-ttv/live_user_themystic7hwd-{width}x{height}.jpg",
  #    "title" => "SHUNDO GIRATINA HUNTING!",
  #    "type" => "live",
  #    "user_id" => "171122649",
  #    "user_name" => "theMYSTIC7hwd",
  #    "viewer_count" => 864
  #  }}
  # user:
  # {:ok,
  #  %{
  #    "broadcaster_type" => "partner",
  #    "description" => "I play Pokémon GO everyday unironically and am the self-proclaimed team leader of Team Mystic. We catch shinies all day SLIDE THROUGH!",
  #    "display_name" => "theMYSTIC7hwd",
  #    "id" => "171122649",
  #    "login" => "themystic7hwd",
  #    "offline_image_url" => "https://static-cdn.jtvnw.net/jtv_user_pictures/f09e413e-54e2-4aba-9594-bc701afc674d-channel_offline_image-1920x1080.jpeg",
  #    "profile_image_url" => "https://static-cdn.jtvnw.net/jtv_user_pictures/fd600e422372c53d-profile_image-300x300.png",
  #    "type" => "",
  #    "view_count" => 632209
  #  }}

  defp channel(user), do: "https://www.twitch.tv/#{user}"

  defp format_time_from_str(time_str) do
    with {:ok, dt, _} <- DateTime.from_iso8601(time_str) do
      # streams['created_at'].strftime("%m/%d/%Y, %H:%M:%S")
      "#{dt.month}/#{dt.day}/#{dt.year}, #{dt.hour}:#{dt.minute}:#{dt.second}"
    end
  end

  def thumbnail(url_template, {width, height}) do
    rep_map = %{"{width}" => "#{inspect(width)}", "{height}" => "#{inspect(height)}"}
    String.replace(url_template, Map.keys(rep_map), fn s -> Map.get(rep_map, s, s) end)
  end

  def id_hook(id) do
    TwitchDB.load_hook(id)
    |> case do
      nil -> ""
      hook -> hook
    end
  end

  def id_hook?(id) do
    id_hook(id)
    |> case do
      "" -> false
      _ -> true
    end
  end

  defp get_thumb(%{"id" => id, "login" => l}, %{"thumbnail_url" => turl}) do
    case id_hook?(id) do
      true -> turl |> thumbnail({640, 360}) |> rehost_jpg(l)
      _ -> {:ok, "fake_thumb"}
    end
  end

  defp stream_message(user_info, stream_info, game_info) do
    with login <- Map.get(user_info, "login"),
         started <- format_time_from_str(Map.get(stream_info, "started_at")),
         channel_url <- channel(login),
         {:ok, thumb_url} <- get_thumb(user_info, stream_info) do
      # streams['created_at'].strftime("%m/%d/%Y, %H:%M:%S")
      %{
        content: Map.get(stream_info, "title"),
        embeds: [
          %{
            title: channel_url,
            url: channel_url,
            color: 6_570_404,
            footer: %{text: started},
            thumbnail: %{
              url: Map.get(user_info, "profile_image_url")
            },
            image: %{url: thumb_url},
            author: %{name: Map.get(user_info, "display_name")},
            fields: [
              %{
                name: "Playing",
                value: Map.get(game_info, "name"),
                inline: true
              },
              %{
                name: "Started at (PST)",
                value: started,
                inline: true
              }
            ]
          }
        ]
      }
    end
  end

  defp get_aws_baseurl() do
    TwitchDiscordConnector.JsonDB.get("digital_ocean_aws")
    |> Map.get("base_url")
  end

  defp get_aws_secrets() do
    case TwitchDiscordConnector.JsonDB.get("digital_ocean_aws") do
      %{"key" => key, "secret" => secret} -> [access_key_id: key, secret_access_key: secret]
      _ -> []
    end
  end
end
