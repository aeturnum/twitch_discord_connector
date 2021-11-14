defmodule TwitchDiscordConnector.Discord do
  @moduledoc """
  The Discord module is used to handle all the discord interactions.any()

  It's a bit messy right now, it does too much with the twitch api, but it's fine for now
  """
  @moduledoc since: "0.1.0"

  alias TwitchDiscordConnector.Util.H
  # alias TwitchDiscordConnector.Discord
  alias TwitchDiscordConnector.Twitch.Common
  alias TwitchDiscordConnector.Twitch.User
  alias TwitchDiscordConnector.JsonDB.AwsDB
  alias TwitchDiscordConnector.Util.L
  alias TwitchDiscordConnector.Template.SrcCall
  alias TwitchDiscordConnector.Template

  @doc """
  Print the JSON that would be sent for twitch user with id `user_id` if they had a discord hook defined.

  This is mostly used for testing and is meant to output to server logs

  Returns A string of JSON usuially.
  """
  def fake_hook(user_id) do
    case get_info(user_id) do
      {:ok, {user, stream, game}} ->
        stream_message("fake_thumbnail.jpg", user, stream, game)
        |> Poison.encode!()
        |> L.ins(label: "Simulated Payload")

      {:error, message} ->
        L.w("Fake hook error: #{message}")
    end
  end

  def template_hook(username, hook) do
    with message <- Template.resolve(stream_template(username)) do
      L.i("Sending payload to discord: #{Poison.encode!(message)}")
      Common.post(%{
        url: hook,
        body: message,
        # print the args and the response
        print: true
      })
    end
  end

  @doc """
  Send the pre-set JSON structure to the .

  This is mostly used for testing and is meant to output to server logs

  Returns A string of JSON usuially.
  """
  def webhook(user_id, hook) do
    L.i("Starting real webhook!")

    case get_info(user_id) do
      {:ok, {user, stream, game}} ->
        try do
          L.d("Testing template lib...")
          template = stream_template(user["login"]) |> Template.resolve()
          L.d("Testing template lib: #{inspect(template)}")
        catch
          _ -> L.d("Testing template lib...FAILED")
        end

        with {:ok, thumb_url} <- get_stream_thumb(user, stream),
             message <- stream_message(thumb_url, user, stream, game) do
          L.i("Sending payload to discord: #{Poison.encode!(message)}")

          Common.post(%{
            url: hook,
            body: message,
            # print the args and the response
            print: true
          })
        end

      {:error, message} ->
        L.w("Fake hook error: #{message}")
    end
  end

  defp get_info(user_id) do
    {:ok, stream} = User.streams_id(user_id) |> L.ins(label: "stream")

    case stream do
      [] ->
        {:error, "User #{inspect(user_id)} no longer streaming."}

      _ ->
        {:ok, game_info} = User.game_info(stream) |> L.ins(label: "game")
        {:ok, user_info} = User.info_id(user_id) |> L.ins(label: "user")

        {:ok, {user_info, stream, game_info}}
    end
  end

  @doc """
  Rehost an image with a unique url based on the account name

  Returns New url of thumbnail.
  """
  def rehost_jpg(jpg_url, account_name) do
    name = image_name(account_name)

    case Common.get(%{url: jpg_url}) do
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
        |> ExAws.request!(AwsDB.secrets())
        |> case do
          %{status_code: 200} ->
            with new_url <- "#{AwsDB.baseurl()}/#{name}" do
              L.i("Rehosted url(#{inspect(jpg_url)}) -> #{new_url}")
              {:ok, new_url}
            end

          other ->
            L.e("Rehosting url(#{inspect(jpg_url)}) -  Upload failed: #{inspect(other)}")
        end

      other ->
        L.e("Rehosting url(#{inspect(jpg_url)}) - get failed: #{inspect(other)}")
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

  def channel(user), do: "https://www.twitch.tv/#{user}"

  def format_time_from_str(time_str) do
    with {:ok, dt, _} <- DateTime.from_iso8601(time_str) do
      # streams['created_at'].strftime("%m/%d/%Y, %H:%M:%S")
      "#{dt.month}/#{dt.day}/#{dt.year}, #{dt.hour}:#{dt.minute}:#{dt.second}"
    end
  end

  @doc """
  Generate a valid thumbnail url given a twitch thumbnail url template.

  Returns Correctly formatted url with proper resolution.
  """
  def thumbnail(url_template, {width, height}) do
    rep_map = %{"{width}" => "#{inspect(width)}", "{height}" => "#{inspect(height)}"}
    String.replace(url_template, Map.keys(rep_map), fn s -> Map.get(rep_map, s, s) end)
  end

  def get_stream_thumb(%{"login" => l}, %{"thumbnail_url" => turl}) do
    turl |> thumbnail({640, 360}) |> rehost_jpg(l)
  end

  defp stream_message(thumb_url, user_info, stream_info, game_info) do
    with login <- Map.get(user_info, "login"),
         started <- format_time_from_str(Map.get(stream_info, "started_at")),
         channel_url <- channel(login) do
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

  def stream_template(username) do
    %{
      "content" => SrcCall.new("twitch.stream", [username], "title"),
      "embeds" => [
        %{
          "title" => SrcCall.new("twitch.channel.url", [username]),
          "url" => SrcCall.new("twitch.channel.url", [username]),
          "color" => 6_570_404,
          "footer" => %{
            "text" =>
              SrcCall.new(
                "twitch.stream.time",
                SrcCall.new("twitch.stream", [username], "started_at")
              )
          },
          "thumbnail" => %{
            "url" => SrcCall.new("twitch.user", [username], "profile_image_url")
          },
          "image" => %{
            "url" =>
              SrcCall.new("twitch.stream.thumbnail", [
                SrcCall.new("twitch.user", [username]),
                SrcCall.new("twitch.stream", [username])
              ])
          },
          "author" => %{"name" => SrcCall.new("twitch.user", [username], "display_name")},
          "fields" => [
            %{
              "name" => "Playing",
              "value" =>
                SrcCall.new(
                  "twitch.game",
                  SrcCall.new("twitch.stream", [username], "game_id"),
                  "name"
                ),
              "inline" => true
            },
            %{
              "name" => "Started at (PST)",
              "value" =>
                SrcCall.new(
                  "twitch.stream.time",
                  SrcCall.new("twitch.stream", [username], "started_at")
                ),
              "inline" => true
            }
          ]
        }
      ]
    }

    # embeds: [
    #   %{
    #     title: channel_url,
    #     url: channel_url,
    #     color: 6_570_404,
    #     footer: %{text: started},
    #     thumbnail: %{
    #       url: Map.get(user_info, "profile_image_url")
    #     },
    #     image: %{url: thumb_url},
    #     author: %{name: Map.get(user_info, "display_name")},
    #     fields: [
    #       %{
    #         name: "Playing",
    #         value: Map.get(game_info, "name"),
    #         inline: true
    #       },
    #       %{
    #         name: "Started at (PST)",
    #         value: started,
    #         inline: true
    #       }
    #     ]
    #   }
    # ]
  end
end
