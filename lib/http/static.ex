defmodule TwitchDiscordConnector.HTTP.Static do
  alias TwitchDiscordConnector.HTTP.Headers

  @static_root [File.cwd!(), "priv"]

  def static(conn, path: []) do
    resp_static(conn, Path.join(@static_root ++ ["index.html"]))
  end

  def static(conn, path: paths) do
    resp_static(conn, Path.join(@static_root ++ paths))
  end

  def resp_static(conn, path) do
    case File.exists?(path) do
      true ->
        conn
        |> Headers.create_headers(mime: MIME.from_path(path))
        |> Plug.Conn.send_file(200, path)

      false ->
        conn |> Plug.Conn.send_resp(404, "File not found")
    end
  end
end
