defmodule Centra.NetworkSupervisor do
  require Logger
  use DynamicSupervisor

  def start_link(_) do
    Logger.info("NetworSupervisor start")
    Registry.start_link(keys: :unique,name: Centra.NetworkSupervisor.Registry)
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    Logger.info("NetworSupervisor init")
    DynamicSupervisor.init(strategy: :one_for_one)
  end



  def add_udp_endpoint(ipstr, port) do
    {:ok, ip} = ipstr
            |> to_charlist
            |> :inet.parse_address

    IO.inspect ip
    DynamicSupervisor.start_child(__MODULE__, { UDPEndpoint,
                  {ip, port} } )
  end

  def add_tcp_endpoint(ipstr, port) do
    {:ok, ip} = ipstr
              |> to_charlist
              |> :inet.parse_address
              
    IO.inspect ip
    DynamicSupervisor.start_child(__MODULE__, { TCPEndpoint,
                  {ip, port} } )
  end

  def get_endpoint(endpoint) do
    IO.inspect endpoint
    [{pid, _}] = Registry.lookup(Centra.NetworkSupervisor.Registry, endpoint)
    pid
  end

  def send_message(local, remote, resp) do
    IO.puts resp
    pid = get_endpoint(local)
    GenServer.call(pid, {:send, remote, resp})
  end

end
