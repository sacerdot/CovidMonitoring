-module(utente).
-export([start/0]).

test(PidUtente)->
    OSPEDALE = global:whereis_name(hospital),
    case OSPEDALE of
        Pid when erlang:is_pid(Pid)  -> 
            D = rand:uniform(4),
            case D of
                1 -> OSPEDALE ! {test_me, PidUtente} ;
                _ -> ok      
            end;
        _ -> 
            io:format("L'ospedale non e' vivo.... riprovo ~n "),
            timer:sleep(2000), % aspetto 2 secondi
            test(PidUtente)                   
    end.

fai_test(PidUtente) ->
    test(PidUtente),
    timer:sleep(3000),
    fai_test(PidUtente).
%viene mandato un messaggio di uscita anticipata e si attende la risposta per essere sicuri di uscire
%da un eventuale luogo prima di uscire
esciluogo(PidPortineria) -> 
    PidPortineria ! {uscita_anticipata,self()},
    receive
        ack -> ok        
    end.

utente(PidSupervisore,PidPortineria)->
    receive
        {'EXIT',PidSupervisore,_Reason}-> %messaggio di uscita dal supervisore
            io:format("E ' morto il supervisore esco. ~n "),
            exit(errore);
        {contact,Pid} ->
            io:format("Sono ~p ho linkato ~p  ~n",[self(),Pid]),
            link(Pid),
            utente(PidSupervisore,PidPortineria);
        {'EXIT',_Pid,quarantena}->
            io:format("Esco vado in quarantena sono ~p  ~n",[self()]),esciluogo(PidPortineria),exit(quarantena);
        {'EXIT',_Pid,positivo}->
            io:format("Esco sono in contatto con positivo sono ~p   ~n",[self()]),esciluogo(PidPortineria),exit(quarantena);
        positive->
            io:format("Esco sono positivo sono l'utente ~p  ~n",[self()]),esciluogo(PidPortineria),exit(positivo);
        
        {'EXIT',_Pid,noproc}->
            % In questo caso e in quello sotto si
            % viene linkati ad un utente che non esiste in quanto
            % l'utente in questione potrebbe essere uscito
            utente(PidSupervisore,PidPortineria);
        {'EXIT',_Pid,noconnection}->
            utente(PidSupervisore,PidPortineria);          
        {'EXIT',_Pid,Reason} ->
            io:format("Uscita anomala io sono l'utente ~p , ragione:  ~p  ~n",[self(),Reason]),exit(Reason)
    end.

init_utente(PidSupervisore,PidPortineria)->
    process_flag(trap_exit,true),utente(PidSupervisore,PidPortineria).

remove_dups([])    -> []; % rimuove i duplicati da una lista fonte https://stackoverflow.com/a/22133154
remove_dups([H|T]) -> [H | [X || X <- remove_dups(T), X /= H]].

integra(Luoghi,_,0)->Luoghi;
integra(Luoghi,Lista,N) ->
    case erlang:length(Lista) of
        0 ->Luoghi;
        _ ->
            Elem = lists:nth(rand:uniform(erlang:length(Lista)),Lista),
            integra(Luoghi ++ [Elem],Lista -- [Elem],N-1)         
    end.

mantiene_lista(Luoghi,PidServer)-> %mantiene la lista luoghi lunga 3
    case erlang:length(Luoghi) of
        X when X < 3 ->
             PidServer ! {get_places,self()},
             receive
                 {places,Lista} ->
                    integra(remove_dups(Luoghi),remove_dups(Lista)--remove_dups(Luoghi) ,3-X)         
             after% dopo 4 secondo se il server non rispode si restituiscono Luoghi
                 4000 ->Luoghi 
             end;
        _ -> Luoghi  % la lista contiene gia' tre luoghi     
    end.

notifica(PidGestore)->% questa funzione 'ricorda' di controllare se nella lista ci sono almeno 3 luoghi
    PidGestore ! controlla,
    timer:sleep(10000),
    notifica(PidGestore).

aggiorna(Luoghi,PidServer)->
    %i luoghi vengono monitorati 
    receive
        {'DOWN', _MonitorReference, process, Pid, normal} ->
            L1 = mantiene_lista(Luoghi -- [Pid],PidServer),
            [monitor(process,X)|| X <- (L1 -- Luoghi)],
            aggiorna(L1,PidServer);

        {'DOWN', _MonitorReference, process, Pid, noconnection} -> 
            L1 = mantiene_lista(Luoghi -- [Pid],PidServer),
            [monitor(process,X)|| X <- (L1 -- Luoghi)],
            aggiorna(L1,PidServer);
        {'DOWN', _MonitorReference, process, Pid, noproc} ->
            L1 = mantiene_lista(Luoghi -- [Pid],PidServer),
            [monitor(process,X)|| X <- (L1 -- Luoghi)],
            aggiorna(L1,PidServer);

        {richiedi,P} -> % il protocolla di visita invia questo messaggio per sapere la lista di luoghi che puo' visitare
            P ! {Luoghi,lista_luoghi} ,aggiorna(Luoghi,PidServer)  ;

        controlla ->%ogni 10 secondi arriva un messaggio per controllare se ci sono 3 luoghi nella lista
            io:format("Controllo ogni 10 secondi se ci sono 3 luoghi da visitare ~n"),
            case erlang:length(Luoghi) of
                X when X < 3 -> % non ci sono 3 luoghi nella lista quindi aggiorno
                    L = mantiene_lista(Luoghi,PidServer),
                    [monitor(process,Y)|| Y <- (L -- Luoghi)],       
                    aggiorna(L,PidServer) ;
                _ -> aggiorna(Luoghi,PidServer) % ci sono almeno 3 luoghi nella lista quindi non faccio nulla                
            end        
    end.

init_lista(PidServer)->
    S = self(),
    L = mantiene_lista([],PidServer),
    [monitor(process,X)|| X <- L ],
    spawn_link(fun()->notifica(S) end), 
    aggiorna(L,PidServer).
%------- funzioni per gestire la visita

% gestisce le entrate e le uscite ovvero si occupa di mandare messaggi 
% di entrata, uscita o uscita anticipata da un luogo
% l'uscita anticipata si verifica nel caso un utente sia risultato positivo o sia entrato in contatto con un positivo o vada in quarantena
portineria(LuogoCorrente)-> 
    receive
        {LUOGO,begin_visit, PidUtente, REF} ->
            LUOGO ! {begin_visit, PidUtente, REF},
            portineria({LUOGO,begin_visit, PidUtente, REF});

        {LUOGO,end_visit, PidUtente, REF}->
            LUOGO ! {end_visit, PidUtente, REF},
            portineria({}) ;
        
        {uscita_anticipata, Pid} ->
            case LuogoCorrente of
                {LUOGO,begin_visit, PidUtente, REF} ->
                    LUOGO ! {end_visit, PidUtente, REF},
                    io:format("Mandata richiesta di uscita anticipata ~n"),
                    Pid ! ack,
                    portineria({}) ;
                _ -> Pid ! ack,
                    portineria({})                    
            end                    
    end.

inizia_visita(L,PidUtente,PidPortineria)->
    case erlang:length(L) of
        0 -> io:format("Non riesco a visitare non ci sono luoghi ~n");
        _ -> %c'e' almeno un elemento nella lista
            REF = erlang:make_ref(),
            LUOGO = lists:nth(rand:uniform(erlang:length(L)),L),
            PidPortineria ! {LUOGO,begin_visit, PidUtente, REF},
            io:format("Sto iniziando la visita del  luogo ~p sono l'utente ~p~n ",[LUOGO,PidUtente]),
            timer:sleep( (rand:uniform(6)+4)*1000 ), %prosegue la visita per 5 - 10 secondi
            io:format("Ho finito la visita del  luogo ~p sono l'utente ~p~n ",[LUOGO,PidUtente]),    
            PidPortineria ! {LUOGO,end_visit, PidUtente, REF}        
    end.

visita(GestoreLista,PidUtente,PidPortineria)->
    GestoreLista ! {richiedi,self()},
    receive
        {L,lista_luoghi} -> inizia_visita(L,PidUtente,PidPortineria)            
    after
        5000 -> io:format("Non riesco ad avere la lista dei luoghi riprovo ~n "),
        visita(GestoreLista,PidUtente,PidPortineria)            
    end.

init_visita(GestoreLista,PidUtente,PidPortineria)->
    visita(GestoreLista,PidUtente,PidPortineria),
    timer:sleep((rand:uniform(3)+2)*1000), %ogni 3-5s (scelta casuale) un utente visita uno dei luoghi nella sua lista
    init_visita(GestoreLista,PidUtente,PidPortineria).

crea_utente()->   
    PidServer = global:whereis_name(server),
    S = self(),
    case PidServer of
        Pid when erlang:is_pid(Pid) ->
            link(Pid),
            PidPortineria = spawn_link(fun () -> portineria({}) end ),
            U = spawn_link(fun()-> init_utente(S,PidPortineria) end )  ,
            L = spawn_link(fun()-> init_lista(Pid) end)  ,
            spawn_link(fun()-> init_visita(L,U,PidPortineria) end),
            spawn_link(fun()-> fai_test(U) end),
            receive
                {'EXIT',_Pid,Reason} ->
                    exit(Reason)                            
            end;
         _ ->
            io:format("Non riesco a contattare il server riprovo ~n "),
            timer:sleep(2000), % aspetto 2 secondi 
            crea_utente()
    end.

start()-> %vengono creati 5 utenti
    [spawn(fun()-> process_flag(trap_exit,true),crea_utente() end) || _ <- lists:seq(1,5) ].
    
