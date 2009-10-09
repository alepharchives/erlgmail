%%%-------------------------------------------------------------------
%%% File    : new_smtp.erl
%%% Author  : Russell Brown <>
%%% Description :  A google mail sender (cribbed from Benjamin Nortier's 21st C code works blog post http://21ccw.blogspot.com/2009/05/how-to-send-email-via-gmail-using.html)
%%%
%%% Created : 14 Jul 2009 by Russell Brown <>
%%%-------------------------------------------------------------------
-module(new_smtp).

-include("config.hrl").

%% API
-export([connect/1,send/2,disconnect/1, timestamp/0]).

%%====================================================================
%% API
%%====================================================================
%%--------------------------------------------------------------------
%% Function: connect
%% Description: connects to googlemail and logs the user in
%%--------------------------------------------------------------------
connect({config, Host, Port, Username, Password}) ->
    case ssl:connect(Host, Port, [{active, false}], 1000) of
        {ok, Socket} ->
            recv(Socket, 0),
            ssl_send(Socket, "HELO localhost"),
            ssl_send(Socket, "AUTH LOGIN"),
            ssl_send(Socket, binary_to_list(base64:encode(Username))),
            ssl_send(Socket, binary_to_list(base64:encode(Password))),
            Socket;
        {error, _} = Err ->
            Err
    end.

%%--------------------------------------------------------------------
%% Function: send
%% Description: sends an email
%%--------------------------------------------------------------------
send(Socket, #email{to=To, header_to=Header_to, from=From, content_type=ContentType, subject=Subject, body=Body}) ->
    ssl_send(Socket, "MAIL FROM: <"++From++">"),
    recpt_to(To, Socket),
    ssl_send(Socket, "DATA"),
    send_no_receive(Socket, "From: <"++From++">"),
    header_to(Header_to, Socket),
    send_no_receive(Socket, timestamp()),
    if ContentType =/= undefined ->
	    send_no_receive(Socket, "Content-Type: " ++ ContentType);
       true -> ok
    end,
    send_no_receive(Socket, "Subject: " ++ Subject),
    send_no_receive(Socket, ""),
    send_no_receive(Socket, Body),
    send_no_receive(Socket, ""),
    ssl_send(Socket, "."),
    Socket.

%%--------------------------------------------------------------------
%% Function: disconnect
%% Description: says bye to the smtp server
%%--------------------------------------------------------------------
disconnect(Socket) ->
    ssl_send(Socket, "QUIT"),
    ssl:close(Socket).

%%====================================================================
%% Internal functions
%%====================================================================
send_no_receive(Socket, Data) ->
    ssl:send(Socket, Data ++ "\r\n").

ssl_send(Socket, Data) ->
    ssl:send(Socket, Data ++ "\r\n"),
    recv(Socket, 0).

recv(Socket, 3) ->
    ssl:close(Socket),
    exit(timeout);
recv(Socket, Times) ->
    case ssl:recv(Socket, 0, 2000) of
        {ok, _} -> ok;
        {error, closed} -> exit(socket_closed);
	{error, timeout} -> recv(Socket, Times+1)
    end.


recpt_to([], _) ->
    ok;
recpt_to([H|T], Socket) ->
    ssl_send(Socket, "RCPT TO:<"++H++">"),
    recpt_to(T, Socket).

header_to([], _) -> ok;
header_to([H|T], Socket) ->
    send_no_receive(Socket, "To: <"++H++">"),
    header_to(T, Socket).

%% "Date: Tue, 15 Jan 2008 16:02:43 +0000"
timestamp() ->
    {Today, {Hour,Min,Sec}} = erlang:localtime(),
    {Year, Month, DayOfMonth} = Today,
    DayOfWeek = calendar:day_of_the_week(Today),
    DayName = httpd_util:day(DayOfWeek),
    MonthName = httpd_util:month(Month),
    TS = io_lib:format("Date: ~s, ~2.10.0B ~s ~4.10.0B ~2.10.0B:~2.10.0B:~2.10.0B +0000", % Added 3 zeroes as milliseconds, iz a hack but harmless
		       [ DayName, DayOfMonth,  MonthName, Year, Hour, Min, Sec]),
    lists:flatten(TS).





