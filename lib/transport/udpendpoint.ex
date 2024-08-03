defmodule UDPEndpoint do
  require Logger
  use GenServer

  defstruct socket: nil,
            local_endpoint: {}
  # Server Callbacks


  def start_link({ip, port}) do
    Logger.info("UDPServer: start link")
    GenServer.start_link(__MODULE__, {ip, port} ,
            name: {:via, Registry, {Centra.NetworkSupervisor.Registry,{:udp, ip, port}}})
  end

  @impl true
  def init({ip, port}) do
    Logger.info("UDPServer: init #{inspect(port)}")
    {:ok, socket} = :gen_udp.open(port, [:binary, active: :once, ip: ip])
    {:ok, %UDPEndpoint{socket: socket, local_endpoint: {:udp,ip,port} } }
  end


  @impl true
  def handle_info({:udp, socket, ip, port, msg}, state) do
    SIPMessage.process_message({state.local_endpoint , {:udp, ip, port}, msg})
    :inet.setopts(socket, active: :once)
    {:noreply, state}
  end

  @impl true
  def handle_call({:send, {:udp, ip, port}, message}, _from, state) do
    IO.puts("Send")
    :gen_udp.send(state.socket,{ip, port}, message)
    {:reply, :ok, state}
  end

  # Client Calls

  @impl true
  def terminate(_reason, state) do
    IO.puts("closing udp ")
    :gen_udp.close(state.socket)
    {:stop, :normal}
  end
end
