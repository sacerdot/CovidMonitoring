-module(utenti).
-export([start/0]).

start()->
    [ spawn(fun utente/0) || _ <- lists:seq(1,500)].

utente()->
    process_flag(trap_exit, true),
    Server = global:whereis_name(server),
    Ospedale = global:whereis_name(hospital),
    link(Server),
    Osp = spawn_link(fun() -> test(Ospedale) end),
    %devo fare link con trap exit Osp perché se crepa Osp(che è l'attore che gestisce l'ospedale (morte interna, devo morire io con il codice positivo).
    Cont = spawn_link(fun contatti/0), %devo fare monitor perchè può fare exit
    %devo fare monitor Cont perché se crepa Cont(che è l'attore che gestisce i contatti (morte esterna), devo morire io con il codice quarantena)
    Vis = spawn_link(fun() -> process_flag(trap_exit, true), richiesta_luoghi([],Cont) end),
    %Vis è l'attore che gestisce le visite, lo monitoriamo in modo tale che se crepa utente crepa anche visita, se crepa visita, viene catturata la morte e respawnato
    Luog = spawn_link(fun() -> luogo(Server, Vis, []) end),
    io:format("L'utente ~p è formato dai seguenti attori:~nOsp=~p~nCont=~p~nVis=~p~nLuog=~p~n", [self(), Osp, Cont, Vis, Luog]),
    receive
        {'EXIT', Osp, positive} -> 
            exit(positive);
        {'EXIT', _, positive} -> 
            exit(quarantena);
        {'EXIT', _, quarantena} -> 
            exit(quarantena);
        {'EXIT', _, REASON} -> 
            io:format('Esco per un errore non catturato. Sono: ~p. Motivo: ~p~n', [self(), REASON]),
            exit(REASON)
    end.

    %Luog è l'attore che chiede ed ottiene la lista dei luoghi da mandare a Vis


%ATTORE Osp
test(Ospedale) ->
    timer:sleep(timer:seconds(30)),
    case rand:uniform(4) of 
        1 ->
            Ospedale ! {test_me,self()},
            receive 
                positive -> 
                    io:format("Sono positivo, ~p~n",[self()]),
                    exit(positive);
                negative -> 
                    io:format("Sono negativo ~p~n",[self()]),
                    test(Ospedale)
            end;
        _ -> 
            io:format("Non devo fare il test, pericolo scampato sono: l'attore con Osp=~p~n",[self()]),
            test(Ospedale)
    end.


%ATTORE Cont
contatti() ->
    receive
        {contact,Pid} -> %l'altro endpoint del protocollo è in luoghi
            link(Pid),
            io:format("L'utente ~p è entrato in contatto con ~p, i Pid si riferiscono a Luog~n",[self(),Pid]),
            contatti()
    end.
    

%ROOT ATTORE Vis
richiesta_luoghi(ListaAttuale, Cont)->
   % process_flag(trap_exit, true),
    receive
        {nuovaLista, L} -> visita_luoghi(L, Cont);
        {'EXIT', _, positive} -> 
            io:format("Dovrei morire di rimbalzo perché sono positivo, sono l'attore con Vis=~p~n", [self()]),
            exit(positive);
        {'EXIT', _, quarantena} -> 
            io:format("Dovrei morire di rimbalzo per quarantena, sono l'attore con Vis=~p~n", [self()]),
            exit(quarantena)
    after  timer:seconds(2 + rand:uniform(3)) -> visita_luoghi(ListaAttuale, Cont)
    end.


%ATTORE Vis
visita_luoghi([],Pid) -> richiesta_luoghi([],Pid);
visita_luoghi(List,Pid)->
            N = rand:uniform(length(List)), %numero casuale per scegliere luogo
            Luogo = lists:nth(N, List), %prendo il luogo scelto alla riga precedente
            Ref = make_ref(),
            Luogo ! {begin_visit, Pid, Ref}, %inizio la visita del luogo usando il Pid di contatti
            io:format("Inizio la visita, sono: l'attore con Vis=~p~n", [self()]),
            receive
                {'EXIT', Pid, quarantena} -> 
                    Luogo ! {end_visit, Pid, Ref},
                    io:format("Finisco la visita per quarantena, sono:l'attore con Vis=~p~n", [self()]),
                    exit(quarantena);
                {'EXIT', Pid, positivo} -> 
                    Luogo ! {end_visit, Pid, Ref},
                    io:format("Finisco la visita perché sono positivo, sono: l'attore con Vis=~p~n", [self()]),
                    exit(positivo)
            after timer:seconds(4 + rand:uniform(6)) ->
                Luogo ! {end_visit, Pid, Ref}, %termino la visita usando sempre il Pid di contatti
                io:format("Finisco la visita, sono: l'attore con Vis=~p~n", [self()]),
                richiesta_luoghi(List, Pid)
            end.
    
    
%ROOT Attore Luog
luogo(Server,Vis,Luoghi) ->
    Server ! {get_places, self()}, %richiede la lista dei luoghi al server
    L = receive 
        {places,PidList} -> aggiungiEl(Luoghi,PidList--Luoghi,3 - length(Luoghi)) %costruisco la lista attuale dei luoghi
    end,
    Vis ! {nuovaLista, L}, %e la mando a Vis 
    %quando il luogo muore, va richiamata la funzione luogo sulla lista meno il luogo morto
    receive
        {'DOWN', _, process, PidLuogo, REASON} -> 
            io:format("Luogo ~p è morto per la ragione: ~p~n", [PidLuogo, REASON]),
            luogo(Server, Vis, Luoghi--[PidLuogo])
    after timer:seconds(10) -> luogo(Server, Vis, Luoghi)
    end.
        
%Attore Luog
% aggiungo N elementi a P prendendoli casualmente da L
% quando N è =< 0 mi stoppo o quando L è vuota
aggiungiEl(ListaAttuale, _, N) when N =< 0 -> ListaAttuale;
aggiungiEl(ListaAttuale,[], _) -> ListaAttuale;
aggiungiEl(ListaAttuale, ListaServer, N) ->
    El = lists:nth(rand:uniform(length(ListaServer--ListaAttuale)), ListaServer -- ListaAttuale),
    monitor(process, El),
    NewP = ListaAttuale ++ [El],
    aggiungiEl(NewP ,ListaServer -- NewP, N-1).

