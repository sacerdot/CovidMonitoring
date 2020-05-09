-module(server1).
-export([init_server/0]).

init_server()->
    process_flag(trap_exit, true),
    server2([]).


server2(Luoghi)->
    receive
        {new_place, PID_LUOGO} -> %richiesta da parte di un luogo di essere aggiunto
            case lists:member(PID_LUOGO,Luoghi) of
                true-> server2(Luoghi);
                false->server2(Luoghi ++ [PID_LUOGO])
            end;
        {get_places, PID} ->
            PID ! {places, Luoghi},server2(Luoghi);
        {ping,P}->
            P ! pong,server2(Luoghi);
        {'EXIT', Pid, _ErrorTerm} -> %attore luogo morto
            case lists:member(Pid,Luoghi) of 
                true ->io:format("Luogo ~p eliminato dalla lista ~n",[Pid]),server2(Luoghi -- [Pid]);
                false -> server2(Luoghi) %quello che e' morto non e' un luogo
            end            
    end.