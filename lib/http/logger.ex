defmodule TwitchDiscordConnector.HTTP.Logger do
  @moduledoc """
  Log requests with the info I want
  """

  require Logger
  alias Plug.Conn
  @behaviour Plug

  def init(opts), do: opts

  # Thank you to: https://timber.io/blog/the-ultimate-guide-to-logging-in-elixir/

  def format(level, message, timestamp, _metadata) do
    "#{fmt_timestamp(timestamp)} [#{level}]  #{message}\n"
  rescue
    _ -> "could not format message: #{inspect({level, message, timestamp})}\n"
  end

  defp fmt_timestamp({date, {hh, mm, ss, ms}}) do
    with {:ok, timestamp} <- NaiveDateTime.from_erl({date, {hh, mm, ss}}, {ms * 1000, 2}),
         time <- NaiveDateTime.to_time(timestamp),
         month_str <- String.pad_leading("#{timestamp.month}", 2, "0"),
         day_str <- String.pad_leading("#{timestamp.day}", 2, "0") do
      "#{month_str}/#{day_str}| #{Time.to_iso8601(time)}"
    end
  end

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
