defmodule TwitchDiscordConnector.Views.Router do
  alias TwitchDiscordConnector.HTTP.Static
  alias TwitchDiscordConnector.Views.Routes
  use Plug.Router

  plug(TwitchDiscordConnector.HTTP.Logger)
  plug(CORSPlug)

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    # todo: add custom parser that will save the raw body to checksum later (https://hexdocs.pm/plug/Plug.Parsers.html)
    json_decoder: Poison
  )

  plug(:match)
  plug(:dispatch)

  # get "/" do
  #   Routes.status(conn, [])
  # end

  get "/hook/stream" do
    Routes.confirm_subscription(conn)
  end

  post "/hook/stream" do
    conn
    |> Plug.Conn.fetch_query_params()
    |> Routes.handle_stream_notification()
  end

  get "/*path" do
    Static.static(conn, path: path)
  end

  match _ do
    Plug.Conn.send_resp(conn, 404, "Not Found")
  end
end
