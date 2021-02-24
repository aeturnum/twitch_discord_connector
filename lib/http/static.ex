defmodule TwitchDiscordConnector.HTTP.Static do
  @moduledoc """
  Helper methods to serve static files.
  """
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
        with {:ok, data} = File.read(path),
             zdata <- :zlib.gzip(data),
             # https://stackoverflow.com/questions/23600229/what-content-type-header-to-use-when-serving-gzipped-files
             headers <- [mime: MIME.from_path(path), content_encoding: "gzip"] do
          conn
          |> Headers.add_headers_to_resp(headers)
          |> Plug.Conn.send_resp(200, zdata)
        end

      false ->
        conn |> Plug.Conn.send_resp(404, "File not found")
    end
  end
end
