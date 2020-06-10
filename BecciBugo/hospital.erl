-module(hospital).
-export([start/0]).

-define(POSITIVEPROB, 25).  % probabilita' di restituire risultato positivo (%)

start() ->
    io:format("CIAO SONO L'OSPEDALE~n"),
    ServerPid = global:whereis_name(server),
    ServerPid ! {ciao, da, ospedale},
    global:register_name(hospital,self()),
    hospital_loop().

hospital_loop() ->
    receive
        {test_me, Pid_User} ->
            case util:probability(?POSITIVEPROB) of
                true -> Pid_User ! positive;
                false -> Pid_User ! negative
            end
    end,
    hospital_loop().
