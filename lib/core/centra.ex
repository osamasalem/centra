defmodule Centra do
  require Logger
  use Application

  def logo, do: ~S(
  ________  _______   ________   _________  ________  ________
 |\   ____\|\  ___ \ |\   ___  \|\___   ___\\   __  \|\   __  \
 \ \  \___|\ \   __/|\ \  \\ \  \|___ \  \_\ \  \|\  \ \  \|\  \
  \ \  \    \ \  \_|/_\ \  \\ \  \   \ \  \ \ \   _  _\ \   __  \
   \ \  \____\ \  \_|\ \ \  \\ \  \   \ \  \ \ \  \\  \\ \  \ \  \
    \ \_______\ \_______\ \__\\ \__\   \ \__\ \ \__\\ _\\ \__\ \__\
     \|_______|\|_______|\|__| \|__|    \|__|  \|__|\|__|\|__|\|__|
)



  @impl true
  @spec start( number(), [ String.t() ]):: {:ok, pid()}
  def start(_argc,_argv) do

    IO.puts logo
    Logger.info("Start Centra", caller: "Centra")
    {:ok, pid} = Centra.GeneralSupervisor.start_link
    #GenServer.call(UDPEndpoint, {:add, port: 5060})
    IO.inspect Centra.NetworkSupervisor.add_udp_endpoint("127.0.0.1", 5060);
    IO.inspect Centra.NetworkSupervisor.add_tcp_endpoint("127.0.0.1", 5060);


    #IO.getn("")
    #Supervisor.stop(pid)
    {:ok, pid}
  end
end
