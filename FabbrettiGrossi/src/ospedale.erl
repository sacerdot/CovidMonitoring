%%%-------------------------------------------------------------------
%%% @doc Modulo ospedale per il progetto del corso di Paradigmi emergenti.
%%% @end
%%%-------------------------------------------------------------------

-module(ospedale).
-export([start/0]).

start() ->
    Result = global:register_name(hospital, self()),
    case Result of
        yes ->
            io:format("L'ospedale si è registrato correttamente.~n"),
            loop();
        no ->
            io:format("Qualcosa è andato storto nella registrazione dell'ospedale.~n")
    end.
%%--------------------------------------------------------------------
%% @doc L'ospedale testa gli utenti e con probabilita' 1/4 risponde
%% risponde positive
%% @end
%%--------------------------------------------------------------------
loop() ->
    receive
        {test_me, Pid} ->
            Result = rand:uniform(4),
            case Result of
                4 -> Pid ! positive;
                _ -> Pid ! negative
            end,
            loop();
        Other -> io:format("Unexpected message: ~p~n", [Other]),
                 loop()
    end.
