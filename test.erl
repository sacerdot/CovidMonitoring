-module(test).
-export([test/0, prova/0]).


prova() ->
    receive
        {msg, N} ->
            io:format("messaggio ricevuto ~p~n", [N])
    end,
    receive
        {rompi, M} ->
            io:format("messaggio ricevuto rompi ~p~n", [M])
    after 30000 -> prova() end.

test() ->

    spawn(server, start, []), %la server_init fa ache lei la spown del server, forse qui basta fare la chiamata alla server init
    util:sleep(1000),
    spawn(hospital, start, []),
    spawn(users, start, []),
    spawn(places, start, []).
