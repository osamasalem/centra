defmodule InviteServerTransaction do
  use GenStateMachine,
    callback_mode: [:handle_event_function, :state_enter]

  require Logger

  defstruct last_response: nil

  def start_link(token) do
    Logger.info("InviteServerTransaction start #{inspect(token)}")

    {:ok, pid} =
      GenStateMachine.start_link(
        __MODULE__,
        :ok,
        name: {:via, Registry, {TransactionUnit.Registry, token}}
      )

    {:ok, pid}
  end

  def init(:ok) do
    Logger.info("InviteServerTransaction init")
    {:ok, :proceeding, %InviteServerTransaction{}}
  end


  def send_response(pid, msg, code, desc) do
    resp = SIPMessage.response_from_request(msg, code, desc)
    :gen_statem.call(pid, {:response, resp})
  end


  def handle_request(pid) do
    :gen_statem.call(pid, :request)
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
    data = %InviteServerTransaction{data | last_response: msg}

    {:next_state, :completed, data,
     [
       {:reply, from, :completed},
     ]}
  end

  def handle_event({:call, from}, {:response, %{first_arg: first_arg} = msg}, :proceeding, data)
      when first_arg >= 100 and first_arg < 200 do
    Logger.info("Proceeding -> Proceeding")
    data = %InviteServerTransaction{data | last_response: msg}
    send_response_internal(msg)
    {:keep_state, data, [{:reply, from, :proceeding}]}
  end

  def handle_event({:call, from}, {:response, %{first_arg: first_arg} = msg}, :proceeding, data)
      when first_arg >= 300 and first_arg < 700 do
    Logger.info("Proceeding -> Completed")
    data = %InviteServerTransaction{data | last_response: msg}
    send_response_internal(msg)
    {:next_state, :completed, data,
      [
        {:reply, from, :completed},
        {:state_timeout, 3_000, :timerG},
        {:state_timeout, 30_000, :timerH}
      ]
    }
  end

  def handle_event(:state_timeout, :timerG, :completed, %{last_response: msg})
      when not is_nil(msg) do
    Logger.info("Completed  -> Completed")
    send_response_internal(msg)
    :keep_state_and_data
  end

  def handle_event(:state_timeout, :timerH, :completed, data) do
    Logger.info("Completed -> Terminated")
    {:next_state, :terminated, data}
  end

  def handle_event({:call, from}, {:response, %{first_arg: first_arg} = msg}, :proceeding, data)
      when first_arg >= 200 and first_arg < 300 do
    data = %InviteServerTransaction{data | last_response: msg}
    Logger.info("Proceeding -> Terminated")
    send_response_internal(msg)
    {:next_state, :terminated, data,
     [
       {:reply, from, :terminated},
     ]}
  end

  def handle_event({:call, from}, :request, %{first_arg: first_arg}, data)
      when first_arg == :register do
    IO.puts("Sending last response")
    send_response_internal(data.last_response)
    {:keep_state, data, [{:reply, from, true}]}
  end

  def handle_event({:call, from}, :request, %{first_arg: first_arg}, data)
      when first_arg == :ack do
    IO.puts("Sending last response")
    send_response_internal(data.last_response)
    {:next_state, :confirmed, data,
      [
        {:reply, from, true},
        {:state_timeout, 30_000, :timerI}
      ]
    }
  end

  def handle_event(:state_timeout, :timerI, :confirmed, _data) do
    Logger.info("Confirmed -> Terminated")
    {:next_state, :terminated, nil}
  end


  def terminate(_, _, _) do
    Logger.info("exit")
  end

  # def callback_mode, do: :state_functions
end
