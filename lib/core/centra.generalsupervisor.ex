defmodule Centra.GeneralSupervisor do
  require Logger
  use Supervisor

  def start_link() do
    Logger.info("GeneralSupervisor start")
    Supervisor.start_link(__MODULE__,
                :ok,
                name: __MODULE__,
                strategy: :one_for_one)
  end

  @impl true
  def init(:ok) do
    Logger.info("GeneralSupervisor init")
    children = [Centra.NetworkSupervisor,TransactionUnit]
    Supervisor.init(children, strategy: :one_for_one)
  end
end
