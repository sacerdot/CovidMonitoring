-module(luogo).
-export([start/0]).

rilevamento_contatti(Nuovo,Lista)->    
    D = rand:uniform(4),
    case Lista of 
        [Testa | Coda] when D =:=1 ->  
            Nuovo ! {contact,Testa},    
            Testa ! {contact,Nuovo},
            rilevamento_contatti(Nuovo,Coda);
        [_|Coda] when D =/=1  -> 
            rilevamento_contatti(Nuovo,Coda);
        []-> ok
    end.

ciclo_di_vita()-> % il luogo ha una probalita' 1/10 di chiudere ogni volta che viene visitato
    D = rand:uniform(10),
    case D of
        1 -> io:format("Esco... sono il luogo: ~p~n",[self()]), exit(normal);
        _ -> ok
    end.

controlla_ref(Mappa,PID_VISITATORE,REF) -> %viene controllato il fatto che le REF dichiarate a inizio e fine visita combacino
    try maps:get(PID_VISITATORE,Mappa) of 
        V when V == REF -> true;
        V when V /= REF -> false
    catch % o Mappa non e' una mappa o la chiave non esiste (non dovrebbe mai essere il caso)
        _:_ -> false
    end.

luogo(Lista,Mappa)->
    %Lista e' la lista dei PID(utenti) presenti nel luogo
    % Mappa e' l'associazione PID => REF
    receive
        {begin_visit, PID_VISITATORE, REF} ->
            case lists:member(PID_VISITATORE,Lista) of
                true ->% il visitatore che vuole entrare e' gia' nel luogo
                    luogo(Lista,Mappa); 
                false ->%il visitatore non e' nel luogo
                    rilevamento_contatti(PID_VISITATORE,Lista),
                    ciclo_di_vita(),% il luogo ha una probalita' 1/10 di chiudere ogni volta che viene visitato
                    luogo(Lista ++ [PID_VISITATORE],
                        try maps:put(PID_VISITATORE,REF,Mappa) of % dal momento che il visitatore non e' nel luogo lo 
                            NuovaMappa -> NuovaMappa              % aggiungo alla lista e alla mappa con try .. catch
                        catch 
                            _:_ -> Mappa
                        end
                        )
            end;
        {end_visit, PID_VISITATORE, REF} ->
            case lists:member(PID_VISITATORE,Lista) of
                true -> 
                    case controlla_ref(Mappa,PID_VISITATORE,REF) of 
                        % controllo che la ref dichiarata all'inizio della visita combaci con quella dichiarata a fine visita 
                        true -> luogo(Lista -- [PID_VISITATORE],maps:remove(PID_VISITATORE,Mappa));
                        false -> luogo(Lista,Mappa)
                    end;                
                false -> luogo(Lista,Mappa)
            end
    end.

crea_luogo()->
    PidServer = global:whereis_name(server),
    case PidServer of %Prima di fare link al server controllo che il server sia vivo 
        Pid when erlang:is_pid(Pid) ->
            link(Pid),
            Pid ! {new_place, self()},
            luogo([],#{});
        _ -> 
            io:format("Il server non e' vivo.... riprovo~n"), 
            timer:sleep(2000), % aspetto 2 secondi 
            crea_luogo()
    end.

start()-> % vengono creati 10 luoghi
    [spawn(fun() -> crea_luogo() end) || _ <- lists:seq(1,10) ].