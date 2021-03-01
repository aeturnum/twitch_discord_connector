defmodule TwitchDiscordConnector.HTTP.Static do
  @moduledoc """
  Helper methods to serve static files.
  """
  alias TwitchDiscordConnector.HTTP.Headers
  alias TwitchDiscordConnector.HTTP.Response

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
        with {:ok, data} = File.read(path) do
          conn
          |> Headers.add_headers_to_resp(mime: MIME.from_path(path))
          |> Response.gzip_response(200, data)
        end

      false ->
        conn |> Plug.Conn.send_resp(404, "File not found")
    end
  end
end
