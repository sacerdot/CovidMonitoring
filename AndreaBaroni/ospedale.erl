-module(ospedale).
-export([start/0]).

ospedale()->
    receive
        {test_me, PID} ->
            D = rand:uniform(4),
            case D of
                1 -> PID ! positive , ospedale();
                _ -> PID ! negative, ospedale()        
            end          
    end.

start()->
    spawn(
        fun()->
            global:register_name(hospital,self()),
            ospedale()
        end
    ).