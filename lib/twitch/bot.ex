# defmodule TwitchDiscordConnector.Twitch.Bot do
#   use Blur.Bot, Application.get_env(:twitch_discord_connector, :init_bot, [])
#   require Logger

#   alias Blur.Message

#   @fcode ~r/\d{4}(.)?\d{4}\1?\d{4}/

#   def handle_in(%Blur.Message{} = msg, state) do
#     Logger.debug("#{msg.channel} #{inspect(msg.tags)} #{inspect(msg.user)}: #{msg.text}")
#     if match_line(msg.text) do
#       delete_message(msg)
#       say(msg.channel, "test")
#     end
#     {:dispatch, msg, state}
#   end

#   def handle_in(%Blur.Notice{} = notice, state) do
#     # Logger.info("#{notice.channel} #{notice.type} #{notice.login}: #{notice.text}")
#     {:dispatch, notice, state}
#   end

#   def match_line(line), do: Regex.match?(@fcode, line)

#   @spec say(binary(), binary()) :: :ok
#   defp say(channel, message), do: send(%Message{channel: channel, text: message})

#   @spec delete_message(Blur.Messsage.t()) :: :ok
#   defp delete_message(m), do: send(%Message{channel: m.channel, text: "/delete #{m.tags["id"]}"})

#   @spec send(Blur.Message.t()) :: :ok
#   defp send(message), do: Blur.Bot.send(self(), message)
# end
