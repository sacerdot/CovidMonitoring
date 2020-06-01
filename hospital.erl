-module(hospital).
-export([start/0]).

hospital() ->
    receive
        {test_me, Pid_User} ->
            case util:probability(25) of
                true -> Pid_User ! {test_result, positive}; 
                false -> Pid_User ! {test_result, negative}
            end
    end,
    hospital().  

start() ->
    io:format("CIAO SONO L'OSPEDALE~n"),
    ServerPid = global:whereis_name(server),
    ServerPid ! {msg_ping, "ciao da ospedale", self()},
    global:register_name(hospital,self()),
    hospital().
