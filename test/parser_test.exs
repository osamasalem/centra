defmodule ParserTest do
  use ExUnit.Case
  doctest Centra

  def getRequest do
    ~s(REGISTER sip:127.0.0.1:5060 SIP/2.0\r
Via: SIP/2.0/UDP 127.0.0.1:60674;branch=z9hG4bK-d8754z-e26d2e66003cbc16-1---d8754z-;rport\r
Max-Forwards: 70\r
Contact: <sip:111@127.0.0.1:60674;rinstance=fcebed9ceb11133b>\r
To: \"Osama\"<sip:111@127.0.0.1:5060>\r
From: \"Osama\"<sip:111@127.0.0.1:5060>;tag=e03bb846\r
Call-ID: MjU3ZTljZTc3YWQ1MjlkNDY3NmQ0NmE1MDdmNTc3MTM.\r
CSeq: 3 REGISTER\r
Expires: 120\r
Allow: INVITE, ACK, CANCEL, OPTIONS, BYE, REGISTER, SUBSCRIBE, NOTIFY, REFER, INFO, MESSAGE\r
Supported: replaces\r
User-Agent: ABC\r
User-Agent: DEF\r
Content-Length: 0\r\n\r\n)
  end

  def getResponse do
    ~s(SIP/2.0 200 OK\r
Via: SIP/2.0/UDP 127.0.0.1:60674;branch=z9hG4bK-d8754z-e26d2e66003cbc16-1---d8754z-;rport\r
Max-Forwards: 70\r
Contact: <sip:111@127.0.0.1:60674;rinstance=fcebed9ceb11133b>\r\n
To: \"Osama\"<sip:111@127.0.0.1:5060>\r
From: \"Osama\"<sip:111@127.0.0.1:5060>;tag=e03bb846\r
Call-ID: MjU3ZTljZTc3YWQ1MjlkNDY3NmQ0NmE1MDdmNTc3MTM.\r
CSeq: 3 REGISTER\r
Expires: 120\r
Allow: INVITE, ACK, CANCEL, OPTIONS, BYE, REGISTER, SUBSCRIBE, NOTIFY, REFER, INFO, MESSAGE\r
Supported: replaces\r
User-Agent: 3CXPhone 6.0.26523.0\r
Content-Length: 0\r\n\r\n)
  end

  test "check the request" do
    msg = ParserTest.getRequest()
    {:ok,  ret} = SIPMessage.parse_message(msg)
    assert length(ret[:headers]) == 13
  end

  test "check the response" do
    msg = ParserTest.getResponse()
    {:ok, ret} = SIPMessage.parse_message(msg)
    assert length(ret[:headers]) == 12
  end

  test "check the header" do
    msg = ParserTest.getRequest()
    {:ok, ret} = SIPMessage.parse_message(msg)
    assert SIPMessage.get_header(ret, "User-Agent") == ["ABC","DEF"]
  end

  test "check the first header" do
    msg = ParserTest.getRequest()
    {:ok,  ret} = SIPMessage.parse_message(msg)
    assert SIPMessage.get_first_header(ret, "User-Agent") == "ABC"
  end

  test "get server transaction token" do
    msg = ParserTest.getRequest()
    {:ok, ret} = SIPMessage.parse_message(msg)
    IO.inspect SIPMessage.get_server_transaction_token(ret, {:tcp,{127,0,0,1},5060})
  end

  test "get new branch token " do

    IO.inspect SIPMessage.generate_branch({127,0,0,1},5060)
    IO.inspect SIPMessage.generate_branch({127,0,0,1},5060)

  end

end
