defmodule NonInviteServerTransaction do
  use GenStateMachine,
    callback_mode: [:handle_event_function, :state_enter]

  require Logger

  defstruct last_response: nil

  def start_link(token) do
    Logger.info("NonInviteServerTransaction start #{inspect(token)}")

    {:ok, pid} =
      GenStateMachine.start_link(
        __MODULE__,
        :ok,
        name: {:via, Registry, {TransactionUnit.Registry, token}}
      )

    {:ok, pid}
  end

  def init(:ok) do
    Logger.info("NonInviteServerTransaction init")
    {:ok, :trying, %NonInviteServerTransaction{}}
  end

  def send_response(pid, msg, code, desc) do
    resp = SIPMessage.response_from_request(msg, code, desc)
    :gen_statem.call(pid, {:response, resp})
  end

  @spec handle_request(atom | pid | {atom, any} | {:via, atom, any}) :: any
  def handle_request(pid) do
    :gen_statem.call(pid, :handle_request)
  end

  defp send_response_internal(msg) do
    IO.inspect(msg)
    resp_msg = SIPMessage.to_string(msg)
    Centra.NetworkSupervisor.send_message(msg.local_endpoint, msg.remote_endpoint, resp_msg)
  end

  def handle_event(:enter, _, :terminated, _data) do
    Logger.info("Terminated")
    {:stop, :normal}
  end

  def handle_event(:enter, _, state, _data) do
    Logger.info("Entering #{Atom.to_string(state)}")
    :keep_state_and_data
  end

  def handle_event({:call, from}, {:response, %{first_arg: first_arg} = msg}, :trying, data)
      when first_arg >= 200 do
    Logger.info("Trying  -> Completed")
    send_response_internal(msg)
    data = %NonInviteServerTransaction{data | last_response: msg}

    {:next_state, :completed, data,
     [
       {:reply, from, :completed},
       {:state_timeout, 30_000, :timerJ}
     ]}
  end

  def handle_event({:call, from}, {:response, msg}, :trying, data) do
    Logger.info("Trying  -> Proceeding")
    data = %NonInviteServerTransaction{data | last_response: msg}
    send_response_internal(msg)
    {:next_state, :proceeding, data, [{:reply, from, :proceeding}]}
  end

  def handle_event({:call, from}, {:response, %{first_arg: first_arg} = msg}, :proceeding, data)
      when first_arg >= 200 do
    data = %NonInviteServerTransaction{data | last_response: msg}
    send_response_internal(msg)
    {:next_state, :completed, data,
     [
       {:reply, from, :completed},
       {:state_timeout, 30_000, :timerJ}
     ]}
  end

  def handle_event({:call, from}, {:response, msg}, :proceeding, data) do
    Logger.info("proceeding")
    data = %NonInviteServerTransaction{data | last_response: msg}
    send_response_internal(msg)
    {:keep_state, data, [{:reply, from, :proceeding}]}
  end

  def handle_event(:state_timeout, :timerJ, :completed, _data) do
    Logger.info("completed -> Terminated")
    {:next_state, :terminated, nil}
  end

  def handle_event({:call, from}, :handle_request, _, %{last_response: nil} = data) do
    {:keep_state, data, [{:reply, from, false}]}
  end

  def handle_event({:call, from}, :handle_request, _, data) do
    IO.puts("Sending last response")
    send_response_internal(data.last_response)
    {:keep_state, data, [{:reply, from, true}]}
  end

  def terminate(_, _, _) do
    Logger.info("exit")
  end

  # def callback_mode, do: :state_functions
end
