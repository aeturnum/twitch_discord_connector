defmodule TwitchDiscordConnector.Event.Helpers do

  alias __MODULE__

  def no_op(), do: :ok
  def no_op_job(), do: {&Helpers.no_op/0, []}

end
