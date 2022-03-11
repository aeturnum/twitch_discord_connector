defmodule TwitchDiscordConnector.Event.Helpers do
  alias __MODULE__

  def no_op(), do: :ok
  def no_op_job(), do: function_call(&Helpers.no_op/0)

  # send to everyone
  # {:brod, name, data \\ nil}
  def broadcast(name, data \\ nil), do: {:brod, name, data}
  # send data to a given address
  # {:send, to, name, data \\ nil} # `to` can be :me or addr
  def send(name, data \\ nil, to \\ :me), do: {:send, to, name, data}
  # call a function with the given args and then send the result to someone
  # {:job, to, name, {function, args}} # `to` can be :me, :brod or addr
  def job(name, function, to \\ :me), do: {:job, to, name, function}
  # delay another action for a given ms
  # {:in, ms, what} # what can be any action
  def delay(delay_ms, action), do: {:in, delay_ms, action}
  def cancel_delay(delay_id), do: {:cancel, delay_id}
  # {:cancel, delay_id} # cancel a delay task
  def function_call(capture, args \\ []), do: {capture, args}
end
