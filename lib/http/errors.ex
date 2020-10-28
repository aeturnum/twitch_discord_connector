defmodule TwitchDiscordConnector.HTTP.Errors do
  def make_error(code, error) do
    {
      :error,
      {code, error_value(error)}
    }
  end

  defp error_value(v) when is_binary(v), do: %{message: v}
  defp error_value(v) when is_map(v), do: v
end
