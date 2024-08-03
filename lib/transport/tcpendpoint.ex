defmodule TCPEndpoint do
  require Logger
  use GenServer

  @tcp_total_timeout 30_000

  defstruct listensocket: nil,
            acceptor_pid: nil,
            local_endpoint: nil,
            ep_sock_map: %{},
            sock_ep_map: %{}

  # Server Callbacks



  def start_link({ip, port}) do
    Logger.info("TCPServer: start link")
    GenServer.start_link(__MODULE__, {ip, port} ,
            name: {:via, Registry, {Centra.NetworkSupervisor.Registry,{:tcp, ip, port}}})
  end

  @impl true
  def init({ip, port}) do
    Logger.info("TCPServer: init #{inspect(port)}")
    {:ok, listensocket } = :gen_tcp.listen(port, [:binary, active: :once, ip: ip])
    pid = spawn(__MODULE__, :acceptor_loop, [self(), listensocket])

    {:ok, %TCPEndpoint{
            listensocket: listensocket,
            acceptor_pid: pid,
            local_endpoint: {:tcp, ip, port}
            } }
  end



  @impl true
  def handle_call({:accept, socket}, _from, state) do
    IO.puts("On Accept")
    {:ok, {ip, port}} = :inet.peername(socket)
    {:ok, tref } = :timer.send_after( @tcp_total_timeout, {:tcp_closed, socket})
    IO.puts("Initiate a new one #{inspect tref}")
    ep_sock_map = Map.put_new(state.ep_sock_map, {:tcp, ip, port}, { socket, tref } )
    sock_ep_map = Map.put_new(state.sock_ep_map, socket, {:tcp, ip, port} )

    {:reply, :ok,  %{ state | ep_sock_map: ep_sock_map,
                                sock_ep_map: sock_ep_map  } }
  end

  @impl true
  def handle_call({:send, {:tcp, ip, port} = dist, message}, _from, state) do
    IO.puts("Send")
    with {:ok, {socket, tref }} <- Map.fetch(state.ep_sock_map, dist)
    do
      IO.puts("Cancelling #{inspect tref}")
      :timer.cancel(tref)
      {:ok, tref} = :timer.send_after( @tcp_total_timeout, {:tcp_closed, socket})
      IO.puts("Initiate a new one #{inspect tref}")
      :inet_tcp.send(socket, message)
      new_val = Map.put(state.ep_sock_map, dist, {socket, tref})

      {:noreply, %{state | ep_sock_map: new_val}}
    else
      :error ->
      nil#:gen_tcp.connect(ip, port, options)
    end
  end

  def acceptor_loop(pid, ls) do
    case :gen_tcp.accept(ls) do
      {:ok, socket} ->
        :inet.setopts(socket, active: :once)
        GenServer.call(pid, {:accept, socket})
        :gen_tcp.controlling_process(socket, pid)
      _ -> nil
    end
    acceptor_loop(pid,ls)
  end



  @impl true
  def handle_info({:tcp, socket, message},state)
            when message != nil do
    {:ok, {ip, port}} = :inet.peername(socket)
    IO.puts("Receive")

    {_, tref } = state.ep_sock_map[{ :tcp, ip, port }]
    IO.puts("Cancelling #{inspect tref}")
    :timer.cancel(tref)
    {:ok, tref} = :timer.send_after( @tcp_total_timeout, {:tcp_closed, socket})
    IO.puts("Initiate a new one #{inspect tref}")

    new_val = Map.put(state.ep_sock_map, { :tcp, ip, port }, {socket, tref})
    SIPMessage.process_message({state.local_endpoint,
                  {:tcp, ip,  port}, message})
    :inet.setopts(socket, active: :once)
    {:noreply, %{state | ep_sock_map: new_val}}
  end

  @impl true
  def handle_info({:tcp_closed, socket}, state) do
    %{^socket => endpoint} = state.sock_ep_map
    :gen_tcp.close(socket)
    {_, tref } = state.ep_sock_map[endpoint]
    IO.puts("Cancelling #{inspect tref}")
    :timer.cancel(tref)
    sock_ep_map = Map.delete(state.sock_ep_map, socket )
    ep_sock_map = Map.delete(state.ep_sock_map, endpoint)
    {:noreply,  %{ state | ep_sock_map: ep_sock_map,
                          sock_ep_map: sock_ep_map  } }
  end

  # Client Calls

  @impl true
  def terminate(reason, state) do
    IO.puts("closing tcp ")
    Process.exit(state.acceptor_pid, reason)
    :gen_tcp.close(state.listensocket)
    nil
  end
end
