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

  # SPA entry point
  get "/" do
    conn
    # |> Logger.log_call()
    |> Static.static(path: ["index.html"])
  end

  get "/live" do
    conn
    |> Routes.live()
  end

  # endpoints for resources
  # /acct/ - account
  # /templ/ - templates

  get "/templ/sources" do
    conn
    # |> Logger.log_call()
    |> Routes.list_template_sources()
  end

  # Twitch callback endpoints

  get "/hook/stream" do
    conn
    |> Logger.log_call()
    |> Routes.confirm_subscription()
  end

  post "/hook/stream" do
    conn
    |> Plug.Conn.fetch_query_params()
    |> Logger.log_call()
    |> Routes.handle_stream_notification()
  end

  # static paths and 404s

  get "/*path" do
    conn
    # |> Logger.log_call()
    |> Static.static(path: path)
  end

  match _ do
    Plug.Conn.send_resp(conn, 404, "Not Found")
  end
end
