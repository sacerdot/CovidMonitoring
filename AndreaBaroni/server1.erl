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
            PID ! {places, Luoghi},
            server2(Luoghi);
        {ping,Ref,P}->
            P ! {pong,Ref},server2(Luoghi);
        {'EXIT', Pid, CAUSA} -> 
            case lists:member(Pid,Luoghi) of % quello che e' uscito e' un luogo
                true  when (CAUSA == normal) -> %un luogo e' uscito normalmente dalla lista
                    io:format("Luogo ~p eliminato dalla lista ~n",[Pid]),server2(Luoghi -- [Pid]);
                true  when (CAUSA /= normal) -> %un luogo non  e' uscito normalmente dalla lista qundi anche il server esce
                    exit(CAUSA);                
                false -> % quello che e' morto non e' un luogo si guarda la causa
                    case CAUSA of
                        normal -> server2(Luoghi);
                        quarantena -> server2(Luoghi); 
                        positivo -> server2(Luoghi); 
                        _ -> exit(CAUSA)        
                    end
            end
                    
    end.