defmodule TwitchDiscordConnector.Views.Router do
  @moduledoc """
  Server router

  todo: save body for checking body signature
  """
  alias TwitchDiscordConnector.HTTP.Static
  alias TwitchDiscordConnector.Views.Routes
  alias TwitchDiscordConnector.HTTP.Logger
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

  get "/" do
    Static.static(conn, path: ["index.html"])
  end

  get "/hook/stream" do
    Routes.confirm_subscription(conn)
    |> Logger.log_call()
  end

  post "/hook/stream" do
    conn
    |> Plug.Conn.fetch_query_params()
    |> Routes.handle_stream_notification()
    |> Logger.log_call()
  end

  get "/*path" do
    Static.static(conn, path: path)
  end

  match _ do
    Plug.Conn.send_resp(conn, 404, "Not Found")
  end
end
