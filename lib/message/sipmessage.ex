defmodule SIPMessage do

  @request_fst_line   ~r/(?<first>[^\s]+)\s+(?<second>[^\s]+)\sSIP\/2.0/
  @response_fst_line  ~r/SIP\/2.0\s+(?<first>\d{3}+)\s+(?<second>[^\s]+)/

  defstruct   local_endpoint: nil,
              remote_endpoint: nil,
              first_arg: "",
              second_arg: "",
              type: :request,
              headers: [],
              payload: ""


  def parse_first_line(line) do
    IO.inspect(line)
    {type, result} = cond do
      (ret = Regex.named_captures(@request_fst_line, line)) != nil ->
        {:request, ret}
      (ret = Regex.named_captures(@response_fst_line, line)) != nil ->
        {:response, ret}
      true -> nil
    end
    %{"first" => first, "second" => second} = result
    {type, first, second}
  end

  def process_message(message) do
    spawn(SIPMessage, :process_message_routine, [message])
  end


  defp reliable?(ep) do
    case ep do
      {:tcp , _, _ } -> true
      {:tls , _, _ } -> true
      {:udp , _, _ } -> false
    end
  end

  defp desc_to_code(code) do
    cond do
      code >= 700 -> "Unknown Error"
      code >= 600 -> "General Error"
      code >= 500 -> "Server generic error"
      code >= 400 -> "Client generic error"
      code >= 300 -> "Redirecting"
      code >= 200 -> "Success"
      code >= 100 -> "Pending"
      true        -> "Unknown Error"
    end
  end


  def process_message_routine({local, remote, msg}) do
    Controller.handle_packet(local, remote, msg)
    # IO.puts msg
    # case parse_message(msg, local, remote) do
    # {:ok, sip} ->
    #   Controller.process_callback(sip.type, sip.first_arg, local, remote, sip)
    # :error -> IO.puts " Invalid message #{msg}"
    # end
  end

  def parse_message(pkt, local, remote) do
    try do
      [body, payload] = String.split(pkt, "\r\n\r\n", parts: 2)
      lines = String.split(body, "\r\n")
      [first_line | headers] = lines
      {type, first, second} = parse_first_line(first_line)
      headers = for hdr <- headers do
        hdr |> String.split(":", parts: 2)
            |> ( fn([k,v]) ->
              {
                k |> String.trim() ,
                v |> String.trim()
              }  end).()
      end

      first = case type do
        :request -> first |> String.downcase(:ascii) |> String.to_atom()
        :response -> first |> Integer.parse()
      end

      msg = %SIPMessage{
        local_endpoint: local,
        remote_endpoint: remote,
        first_arg: first,
        second_arg: second,
        type: type,
        headers: headers,
        payload: payload }
        {:ok, msg} #Controller.handle_message(msg.type, msg.first_arg, msg)
    rescue
        _ -> :error #_ -> Controller.handle_message(:error, local, remote, pkt)
    end
  end

  def response_from_request(sip_msg, code, message \\ "") do
    message = if message == "" do desc_to_code(code) else message end
    %{sip_msg | type: :response, first_arg: code, second_arg: message }
  end

  def to_string(sip_msg) do
    case sip_msg.type do
      :request -> "#{sip_msg.first_arg} #{sip_msg.second_arg} SIP/2.0\r\n"
      :response -> "SIP/2.0 #{sip_msg.first_arg} #{sip_msg.second_arg}\r\n"
    end <> Enum.map_join(sip_msg.headers, "\r\n",
              fn({a,b}) -> "#{a}: #{b}" end)
        <> "\r\n\r\n #{sip_msg.payload}"
  end

  def get_header(msg, hdr) do
    hdr = hdr |> String.downcase(:ascii)
    msg.headers
      |> Enum.filter(
        fn({k, _}) ->
          String.downcase(k, :ascii) == String.downcase(hdr, :ascii)
        end )
      |> Enum.map(fn({_, v}) -> v end)
  end

  def get_first_header(msg, hdr) do
    hdr = hdr |> String.downcase(:ascii)
    msg.headers
      |> Enum.find(
        fn({k, _}) ->
          String.downcase(k, :ascii) == String.downcase(hdr, :ascii)
        end )
      |> elem(1)
  end

  def generate_branch(ip, port) do
    token = Enum.to_list(?A..?Z)
          ++ Enum.to_list(?a..?z)
          ++ Enum.to_list(?0..?9)
          ++ [?-, ?.,  ?_, ?+ ]
          |> Enum.take_random(32)
    timestamp = DateTime.utc_now
              |> DateTime.to_unix(:millisecond)
              |> Integer.mod(10*60*1000)
              |> Integer.to_string
    ip = "#{ (Tuple.to_list(ip) |> Enum.join("-")) }"
    "z9hG4bK#{timestamp}#{token}@#{ip}.centra.local:#{port}"
  end

  @spec generate_sip_request(String.t, String.t):: %SIPMessage{}
  def generate_sip_request(arg, sipuri) do
      %SIPMessage{type: :request,
                  first_arg: arg,
                  headers: [],
                  second_arg: sipuri,
                  payload: "" }
  end

  @spec add_header(%SIPMessage{}, String.t, String.t) :: %SIPMessage{}
  def add_header(msg, key , value) do
    %SIPMessage{ msg | headers: List.insert_at(msg.headers, -1, {key, value})}
  end


end
