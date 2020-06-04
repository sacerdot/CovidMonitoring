-module(ospedale).
-export([start/0]).


% Protocollo di test
test() -> 
    receive
        {test_me,Pid} -> 
            case rand:uniform(4) of
                 1 -> Pid ! positive, test();
                 _ -> Pid ! negative, test()
            end
    end.


% Creazione Ospedale
ospedale()->
    global:register_name(hospital,self()),
    test().


% Avvio ospedale in attore
start() ->
    spawn(fun ospedale/0).
