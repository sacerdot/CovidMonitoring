-module(luogo).
-export([init_luogo/0,controlla/1]).

controlla(Pid)->
    Pid ! {ping,self()},
    receive
        pong -> io:format("Ho ricevuto true ~n"), true
    after 4000 -> false
    end.
    
init_luogo()->   
    PidServer= global:whereis_name(server),
    case controlla(PidServer) of %Prima di fare link al server controllo che il server sia vivo
        true ->link(PidServer),luogo([],#{});
        false -> io:format("Il server non e' vivo "), exit(server_non_vivo)
    end.

controlla_ref(Mappa,PID_VISITATORE,REF) -> %viene controllato il fatto che le REF dichiarate a inizio e fine visita combacino
    try maps:get(PID_VISITATORE,Mappa) of 
        V when V == REF -> true;
        V when V /= REF -> false
    catch % o Mappa non e' una mappa o la chiave non esiste (non dovrebbe mai essere il caso)
        _:_ -> false
    end.

rilevamento_contatti()->ok.

luogo(Lista,Mappa)->
    %Lista e' la lista dei PID(utenti) presenti nel luogo
    % Mappa e' l'associazione PID => REF
    receive
        {begin_visit, PID_VISITATORE, REF} ->
            case lists:member(PID_VISITATORE,Lista) of
                true -> luogo(Lista,Mappa); % il visitatore che vuole entrare e' gia' nel luogo
                false -> luogo(Lista ++ [PID_VISITATORE],
                try maps:put(PID_VISITATORE,REF,Mappa) of % dal momento che il visitatore non e' nel luogo lo 
                    NuovaMappa -> NuovaMappa              % aggiungo alla lista e alla mappa con try .. catch
                catch 
                    _:_ -> Mappa
                end
                )
            end;
        {end_visit, PID_VISITATORE, REF} ->
            case lists:member(PID_VISITATORE,Lista) of
                true -> controlla_ref(Mappa,PID_VISITATORE,REF) ;
                false -> luogo(Lista,Mappa)
            end
    end.


