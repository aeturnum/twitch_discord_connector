defmodule TwitchDiscordConnector.HTTP.Logger do
  require Logger
  alias Plug.Conn
  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _opts) do
    start = System.monotonic_time()

    Conn.register_before_send(conn, fn conn ->
      Logger.log(:info, fn ->
        stop = System.monotonic_time()
        diff = System.convert_time_unit(stop - start, :native, :microsecond)

        [request_info(conn, diff)]
      end)

      conn
    end)
  end

  defp request_info(conn, delta) do
    [
      connection_path(conn),
      connection_type(conn),
      connection_result(conn),
      formatted_diff(delta)
    ]
    |> Enum.join(" ")
  end

  defp connection_type(%{state: :chunked}), do: "Chunked"
  defp connection_type(_), do: "Sent"

  defp connection_path(%{method: method, request_path: path}), do: "#{method} #{path} ->"

  defp connection_result(%{status: status_code}), do: "#{status_code} in"

  defp formatted_diff(diff) when diff > 1000, do: [diff |> div(1000) |> Integer.to_string(), "ms"]
  defp formatted_diff(diff), do: [diff |> Integer.to_string(), "µs"]
end
