-module(ospedale).
-export([start/0, loop/0]).


start() ->
    Result = global:register_name(hospital, self()),
    case Result of
        yes -> 
            io:format("L'ospedale si è registrato correttamente.~n"),
            loop();
        no -> 
            io:format("Qualcosa è andato storto nella registrazione dell'ospedale.~n")
    end.

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
