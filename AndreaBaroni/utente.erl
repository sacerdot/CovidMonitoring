-module(utente).
-export([init_utente/0,init_visita/2,init_lista/1,init_general/0]).



integra(Luoghi,_,0)->Luoghi;
integra(Luoghi,Lista,N) ->
    case erlang:length(Lista) of
        0 ->Luoghi;
        _ ->
            Elem = lists:nth(rand:uniform(erlang:length(Lista)),Lista),
            integra(Luoghi ++ [Elem],Lista -- [Elem],N-1)         
    end.



mantiene_lista(Luoghi,PidServer)->
    io:format("La lista e ~p~n ",[Luoghi]),
    case erlang:length(Luoghi) of
        X when X < 3 ->
             PidServer ! {get_places,self()},
             receive
                 {places,Lista} ->
                    io:format("La lista e ~p~n ",[Lista]),
                    integra(utils:remove_dups(Luoghi),utils:remove_dups(Lista)--utils:remove_dups(Luoghi) ,3-X)         
             after% dopo 4 secondo se il server non rispode si restituiscono Luoghi
                 4000 ->Luoghi 
                     
             end;
        _ -> Luoghi  % la lista contiene gia' tre luoghi     
    end.

aggiorna(Luoghi,PidServer)->
    receive
        {'EXIT',Pid,normal} ->
            L1 = mantiene_lista(Luoghi -- [Pid],PidServer),
            [link(X)|| X <- (L1 -- Luoghi)],       
            aggiorna(L1,PidServer);

        {'EXIT',_Pid,CAUSA} -> 
            exit(CAUSA);

        {richiedi,P} -> P ! {Luoghi,lista_luoghi} ,aggiorna(Luoghi,PidServer)  

    after
        10000 ->
            L = mantiene_lista(Luoghi,PidServer),
            [link(X)|| X <- (L -- Luoghi)],       
            aggiorna(L,PidServer)         
    end.

init_lista(PidServer)->
    process_flag(trap_exit,true),
    L = mantiene_lista([],PidServer),
    [link(X)|| X <- L ], 
    aggiorna(L,PidServer).




inizia_visita(L,PidUtente)->
    case erlang:length(L) of
        0 -> io:format("Non riesco a visitare non ci sono luoghi");
        _ -> %c'e' almeno un elemento nella lista
            REF = erlang:make_ref(),
            LUOGO = lists:nth(rand:uniform(erlang:length(L)),L),
            LUOGO ! {begin_visit, PidUtente, REF},
            io:format("Sto iniziando la visita del  luogo ~p sono l'utente ~p~n ",[LUOGO,PidUtente]),
            timer:sleep( (rand:uniform(6)+4)*1000 ), %prosegue la visita per 5 - 10 secondi
            io:format("Ho finito la visita del  luogo ~p sono l'utente ~p~n ",[LUOGO,PidUtente]),
            
            LUOGO ! {end_visit, PidUtente, REF}        
    end.

visita(GestoreLista,PidUtente)->

    GestoreLista ! {richiedi,self()},
    receive
        {L,lista_luoghi} -> inizia_visita(L,PidUtente)
            
    after
        5000 -> io:format("Non riesco ad avere la lista dei luoghi riprovo ~n "),
        visita(GestoreLista,PidUtente)
            
    end.

init_visita(GestoreLista,PidUtente)->
    visita(GestoreLista,PidUtente),
    timer:sleep((rand:uniform(3)+2)*1000), %ogni 3-5s (scelta casuale) un utente visita uno dei luoghi nella sua lista
    init_visita(GestoreLista,PidUtente).

utente()->
    receive
        {contact,Pid} -> link(Pid),utente();
        {'EXIT',_Pid,quarantena}->
            io:format("Esco vado in quarantena ~n"),exit(quarantena);
        {'EXIT',_Pid,positivo}->
            io:format("Esco sono positivo ~n"),exit(positivo);
        {'EXIT',_Pid,Reason} ->
            io:format("Uscita anomala ~n"),exit(Reason)
    end.

init_utente()->
    process_flag(trap_exit,true),utente().

init_general()->
    PidServer = global:whereis_name(server),
    case utils:controlla(PidServer) of
        true ->
            link(PidServer),
            U = spawn_link(?MODULE,init_utente,[])  ,
            L = spawn_link(?MODULE,init_lista,[PidServer])  ,
            spawn_link(?MODULE,init_visita,[L,U]);

        false->
            io:format("Non riesco a contattare il server riprovo ~n "),
            init_general()
    end.
    
