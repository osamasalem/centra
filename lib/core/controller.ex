defmodule Controller do
  alias TransactionUnit, as: TU

  @spec handle_packet(any, any, any) :: none()
  def handle_packet(local, remote, msg) do
    TU.process_message(msg, local, remote)
    nil
  end

  def handle_message(:error, _local, _remote, msg) do
    IO.puts " Invalid message #{msg}"
    nil
  end

  #@spec handle_message(atom(), atom(), %SIPMessage{}) :: any()

  @spec handle_message(any, any, any) :: none
  def handle_message(:request, :register, msg) do
    TU.send_response(msg, 200, "OK")
    nil
  end

  def handle_message(:request, :subscribe, msg) do
    TU.send_response(msg, 200, "OK")
    nil
  end

  def handle_message(:request, :invite, %SIPMessage{} = msg) do
    TU.send_response(msg, 180, "Ringing")

    IO.inspect(msg)
    #ts = DateTime.utc_now() |> DateTime.to_unix()
    ts = :rand.uniform(999_999_999)
    #sess_id = :rand.uniform(1000_000_000)
    sess_id = :rand.uniform(999_999_999)
    port = :rand.uniform(60_000) + 4_000

    payload = """
    v=0\r
    o=Centra #{sess_id} #{ts} IN IP4 127.0.0.1\r
    s=Centra-Call\r
    c=IN IP4 127.0.0.1\r
    t=0 0\r
    m=audio #{port} RTP/AVP 0 8 3 101\r
    a=rtpmap:0 PCMU/8000\r
    a=rtpmap:8 PCMA/8000\r
    a=rtpmap:3 GSM/8000\r
    a=rtpmap:101 telephone-event/8000\r
    m=video 5004 RTP/AVP 96\r
    a=rtpmap:96 VP8/90000\r
    a=fmtp:101 0-15\r
    a=ptime:20\r
    a=sendrecv\r\n\r
    """
    IO.inspect payload
    IO.puts "Size = #{String.length(payload)}"

    msg = %{ msg | payload: payload,
                    headers: List.keyreplace(msg.headers, "Content-Length", 0, {"Content-Length",String.length(payload)})}

    IO.inspect msg
    TU.send_response(msg, 200, "Ok")
  end

end
