defmodule TwitchDiscordConnector.Views.Routes do
  @moduledoc """
  Route bodies
  """

  # alias TwitchDiscordConnector.HTTP.Response
  alias TwitchDiscordConnector.Event
  alias TwitchDiscordConnector.Twitch.Subs
  alias TwitchDiscordConnector.Util.L

  # def status(conn, []) do
  #   {:ok, %{"status" => "200 ok"}}
  #   |> Response.send_response(conn)
  # end

  def confirm_subscription(conn) do
    with conn <- Plug.Conn.fetch_query_params(conn),
         %{"hub.challenge" => challenge, "hub.topic" => topic} = conn.query_params,
         user_id <- Subs.id_from_topic(topic) do
      case Subs.exists?(user_id) do
        # must respond with plain body
        # todo: note if a sub is confirmed or not
        true ->
          IO.puts("Confirming subscription to #{topic}")
          Plug.Conn.send_resp(conn, 200, challenge)

        false ->
          Plug.Conn.send_resp(conn, 404, "Not Found")
      end
    end
  end

  def handle_stream_notification(conn) do
    user_id = Map.get(conn.query_params, "user_id", "0")

    L.d(
      "handle_stream_notification:
      \n\tquery: #{inspect(conn.query_string)}
      \n\t#{inspect(conn.body_params)}
      \n\tchecksum:#{
        TwitchDiscordConnector.Twitch.Subs.sig_valid?(
          user_id,
          conn.req_headers,
          conn.body_params
        )
      }"
    )

    case conn.body_params do
      %{"data" => []} ->
        L.w(~s(Stream ended for #{inspect(user_id)}?))

      # Event.broadcast({:twitch, :stream}, {:ended, user_id})

      %{"data" => [stream]} ->
        L.i(~s(Stream update for for #{stream["user_name"]}: #{stream["title"]}))
        Event.broadcast({:twitch, :stream}, {:up, user_id, stream})
    end

    Plug.Conn.send_resp(conn, 200, "Thank you!")
  end
end
