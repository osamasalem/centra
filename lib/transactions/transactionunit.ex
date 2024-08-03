defmodule TransactionUnit do
  use GenServer
  require Logger

  @branch_pattern     ~r/branch=(?<branch>[^\s;]+)/
  @cseq_pattern       ~r/\d+\s+(?<verb>[^\s]+)/


  def start_link(_) do
    Logger.info("Transaction start")
    Registry.start_link(keys: :unique,name: TransactionUnit.Registry)
    GenServer.start_link( __MODULE__, :ok, name: __MODULE__)
  end

  def create_transaction(msg) do
    token = get_server_transaction_token(msg, msg.remote_endpoint)
    {:ok, pid} = case token do
      {:server, _ , _, :invite} -> InviteServerTransaction.start_link(token);
      {:server, _ , _, _} -> NonInviteServerTransaction.start_link(token);
    end
    pid
  end

  def get_transaction(msg) do
    token = get_server_transaction_token(msg, msg.remote_endpoint)
    case Registry.lookup(TransactionUnit.Registry, token) do
      [{pid, _}] -> pid
      _ -> nil
    end
  end

  def send_response(msg, code, desc) do
    IO.inspect(get_transaction(msg))
    pid = get_transaction(msg) || create_transaction(msg)
    resp = SIPMessage.response_from_request(msg, code, desc)
    :gen_statem.call(pid, {:response, resp})
  end


  @spec get_server_transaction_token(atom | %{headers: any}, any) :: {:server, any, any, atom}
  def get_server_transaction_token(msg , ep) do
    via = SIPMessage.get_first_header(msg, "via")
    %{"branch" => branch} = Regex.named_captures(@branch_pattern, via)
    cseq = SIPMessage.get_first_header(msg, "cseq")
    %{"verb" => verb} = Regex.named_captures(@cseq_pattern, cseq)
    verb = verb
           |> String.downcase(:ascii)
           |> String.to_atom()
    {:server, branch, ep, verb}
  end

  def process_message(msg, local, remote) do
    case SIPMessage.parse_message(msg, local, remote) do
      {:ok, sip} ->
        token = get_server_transaction_token(sip, sip.remote_endpoint)
        with  [{pid, _}] <- Registry.lookup(TransactionUnit.Registry, token),
              true <- :gen_statem.call(pid, {:request, msg})
        do
          nil
        else
          _ -> Controller.handle_message(sip.type, sip.first_arg, sip)
        end
      :error ->
        Controller.handle_message(:error, local, remote, msg)
    end

  end
  # def send_response(msg, code, local ,remote) do
  #   resp =  SIPMessage.response_from_request(msg, code)
  #   resp_msg = SIPMessage.to_string(resp)
  #   #TU.handle_response(resp,remote)
  #   NS.send_message(local, remote, resp_msg)
  # end

  @impl true
  def init(:ok) do
    Logger.info("Transaction start")
    {:ok, :ok }
  end

end
