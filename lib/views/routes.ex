defmodule TwitchDiscordConnector.Views.Routes do
  @moduledoc """
  Route bodies
  """

  alias TwitchDiscordConnector.HTTP.Response
  alias TwitchDiscordConnector.Event
  alias TwitchDiscordConnector.Twitch.Subs
  alias TwitchDiscordConnector.Template.SrcServer
  alias TwitchDiscordConnector.Util.Live

  alias TwitchDiscordConnector.Util.L

  def live(conn) do
    Plug.Conn.send_resp(conn, 200, Live.get_ref())
  end

  def list_template_sources(conn) do
    {:ok, SrcServer.list(true)}
    |> Response.send_response(conn)
  end

  # {
  #   "challenge": "pogchamp-kappa-360noscope-vohiyo",
  #   "subscription": {
  #     "id": "f1c2a387-161a-49f9-a165-0f21d7a4e1c4",
  #     "status": "webhook_callback_verification_pending",
  #     "type": "channel.follow",
  #     "version": "1",
  #     "cost": 1,
  #     "condition": {
  #       "broadcaster_user_id": "12826"
  #     },
  #     "transport": {
  #       "method": "webhook",
  #       "callback": "https://example.com/webhooks/callback"
  #     },
  #     "created_at": "2019-11-16T10:11:12.123Z"
  #   }
  # }

  def handle_sub_webhook(conn) do
    case conn.body_params do
      %{"challenge" => challenge, "subscription" => sub} ->
        user_id = Subs.id_from_sub(sub)
        %{"type" => type} = sub

        if Subs.exists?(user_id, type) do
          L.i("Confirming subscription to #{Map.get(sub, "type", "?")}::#{user_id}")
          Plug.Conn.send_resp(conn, 200, challenge)
        else
          L.w("Could not find sub #{user_id}::#{type}")
          Plug.Conn.send_resp(conn, 404, "Not Found")
        end

      #   %{
      #     "event" => %{
      #       "broadcaster_user_id" => "503254",
      #       "broadcaster_user_login" => "aeturnum",
      #       "broadcaster_user_name" => "aeturnum",
      #       "id" => "45799850397",
      #       "started_at" => "2022-03-10T16:35:00Z",
      #       "type" => "live"
      #     },
      #     "subscription" => %{
      #       "condition" => %{"broadcaster_user_id" => "503254"},
      #       "cost" => 1,
      #       "created_at" => "2022-03-10T16:32:49.659178473Z",
      #       "id" => "a596f07d-1e22-4422-b6b2-73f53ec68b1d",
      #       "status" => "enabled",
      #       "transport" => %{
      #         "callback" => "https://twitch.naturecultur.es/hook/stream?user_id=503254", "method" => "webhook"
      #       },
      #       "type" => "stream.online", "version" => "1"}
      # }
      data = %{"event" => event, "subscription" => sub} ->
        user_id = Map.get(event, "broadcaster_user_id", "0")
        type = Map.get(sub, "type", "unknown")
        L.i(~s(Stream event #{type} for for #{event["broadcaster_user_name"]}))

        Event.broadcast({:twitch, :stream}, {type, user_id, data})

        Plug.Conn.send_resp(conn, 200, "Thank you!")

      %{"data" => [stream]} ->
        user_id = Map.get(conn.query_params, "user_id", "0")

        Event.broadcast({:twitch, :stream}, {:up, user_id, stream})
    end
  end
end
