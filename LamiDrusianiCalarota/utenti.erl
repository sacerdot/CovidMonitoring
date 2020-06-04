-module(utenti).
-export([start/0]).


% Avvio utenti in N attori (N = 5)
start()->
    [spawn(fun utente/0) || _ <- lists:seq(1,5)].


% Avvio utente padre
utente()->
    process_flag(trap_exit, true),
    Server = global:whereis_name(server),
    Ospedale = global:whereis_name(hospital),
    link(Server),
    % Figlio per testare positività utente
    Osp = spawn_link(fun() -> test(Ospedale) end),
    % Figlio per per gestire i contatti fra utenti
    Cont = spawn_link(fun contatti/0),
    % Figlio per gestire visite dei luoghi
    % resiste alla morte per poter finere la visita prima di morire
    Vis = spawn_link(fun() -> process_flag(trap_exit, true), richiesta_luoghi([],Cont) end),
    % Figlio per gestire la lista dei luoghi che si possono visitare
    Luog = spawn_link(fun() -> luogo(Server, Vis, []) end),
    io:format("L'utente ~p è formato dai seguenti attori:~nOsp=~p~nCont=~p~nVis=~p~nLuog=~p~n", [self(), Osp, Cont, Vis, Luog]),
    % gestione delle morti dei vari attori figli
    receive
        {'EXIT', Osp, positive} -> 
            exit(positive);
        {'EXIT', _, positive} -> 
            exit(quarantena);
        {'EXIT', _, quarantena} -> 
            exit(quarantena);
        {'EXIT', _, REASON} -> 
            io:format('Esco per un errore sconosciuto. Sono: ~p. Motivo: ~p~n', [self(), REASON]),
            exit(REASON)
    end.


% ATTORE Osp
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


% ATTORE Cont
contatti() ->
    receive
        {contact,Pid} ->
            % Esiste la possibilità che l'utente contagiante muoia prima che riesca a linkarmi
            try 
                link(Pid) 
            of 
               _ -> 
                    io:format("L'utente ~p è entrato in contatto con ~p, i Pid si riferiscono a Luog~n",[self(),Pid]),
                    contatti() 
            catch 
                error:noproc -> 
                    exit(quarantena) %perchè la probabilità del contatto era positiva ( si sarebbe anche potuto lasciare vivo) 
            end 
    end.


% ROOT ATTORE Vis
richiesta_luoghi(ListaAttuale, Cont)->
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


% ATTORE Vis
visita_luoghi([],Pid) -> richiesta_luoghi([],Pid); %non faccio la visita perchè non ho luoghi da visitare
visita_luoghi(List,Pid)->
    N = rand:uniform(length(List)), %numero casuale per scegliere luogo
    Luogo = lists:nth(N, List), %prendo il luogo scelto alla riga precedente
    Ref = make_ref(),
    Luogo ! {begin_visit, Pid, Ref}, %inizio la visita del luogo usando il Pid di contatti
    io:format("Inizio la visita, sono: l'attore con Vis=~p~n", [self()]),
    receive % se muore durante una visita finisce prima la visita e poi muore
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


% ROOT Attore Luog
luogo(Server,Vis,Luoghi) ->
    Server ! {get_places, self()}, %richiede la lista dei luoghi al server
    L = receive 
        {places,PidList} -> aggiungiEl(Luoghi,PidList--Luoghi,3 - length(Luoghi)) %costruisco la lista attuale dei luoghi
    end,
    Vis ! {nuovaLista, L}, %mando la lista dei luoghi che posso visitare all'attore Vis  
    receive  %quando il luogo muore, va richiamata la funzione luogo sulla lista meno il luogo morto
        {'DOWN', _, process, PidLuogo, REASON} -> 
            io:format("Luogo ~p è morto per la ragione: ~p~n", [PidLuogo, REASON]),
            luogo(Server, Vis, Luoghi--[PidLuogo])
    after timer:seconds(10) -> luogo(Server, Vis, Luoghi)
    end.


% Attore Luog
% aggiungo N elementi a lista attuale prendendoli casualmente da lista del server 
% quando N =< 0 mi stoppo o quando la lista del server è vuota
aggiungiEl(ListaAttuale, _, N) when N =< 0 -> ListaAttuale;
aggiungiEl(ListaAttuale,[], _) -> ListaAttuale;
aggiungiEl(ListaAttuale, ListaServer, N) ->
    Luogo = lists:nth(rand:uniform(length(ListaServer--ListaAttuale)), ListaServer -- ListaAttuale),
    monitor(process, Luogo), % monitor del luogo per poter aggiornare la lista quando muore
    NewP = ListaAttuale ++ [Luogo],
    aggiungiEl(NewP ,ListaServer -- NewP, N-1).
