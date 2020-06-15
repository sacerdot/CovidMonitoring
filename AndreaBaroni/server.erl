-module(server).
-export([start/0]).

server(Luoghi)->
    receive
        {new_place, PID_LUOGO} -> %richiesta da parte di un luogo di essere aggiunto
            case lists:member(PID_LUOGO,Luoghi) of
                true-> server(Luoghi);
                false->server(Luoghi ++ [PID_LUOGO])
            end;
        {get_places, PID} ->
            io:format("Numero di luoghi registrati al server: ~p ~n ", [erlang:length(Luoghi)] ),
            PID ! {places, Luoghi},
            server(Luoghi);
        {'EXIT', Pid, CAUSA} -> % il server riceve questo messaggio se un attore a lui linkato direttamente o indirettamente esce
            case lists:member(Pid,Luoghi) of % quello che e' uscito e' un luogo
                true  when (CAUSA == normal) -> %un luogo e' uscito normalmente dalla lista
                    io:format("Luogo ~p eliminato dalla lista ~n",[Pid]),server(Luoghi -- [Pid]);
                true  when (CAUSA /= normal) -> %un luogo non  e' uscito normalmente dalla lista qundi anche il server esce
                    io:format(" 1 Sono il server esco per causa ~p~n",[CAUSA]), 
                    erlang:exit(CAUSA);                
                false -> % quello che e' morto non e' un luogo si guarda la causa
                    case CAUSA of
                        normal -> server(Luoghi);
                        quarantena -> server(Luoghi); 
                        positivo -> server(Luoghi); 
                        Y ->
                            io:format("Sono il server esco per causa ~p~n",[Y]),  
                            erlang:exit(CAUSA)  % un attore linkato al server e' uscito in modo anormale      
                    end
            end
                    
    end.
    
start()->
    spawn(
        fun() ->
            erlang:process_flag(trap_exit, true),
            Ris = global:register_name(server,erlang:self()),
            case Ris of
                yes -> server([]);
                no -> io:format("Non e' possibile registrare il server ~n "), erlang:exit(ko)        
            end
        end
    ).