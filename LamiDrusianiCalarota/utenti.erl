-module(utenti).
-export([start/0,test/1,contatti/0, richiesta_luoghi_prima_volta/1, luogo/3]).

start()-> utente().

utente()->
    process_flag(trap_exit, true),
	Server = global:whereis_name(server),
	Ospedale = global:wheris_name(hospital),
	link(Server),
    Osp = spawn(?MODULE, test, [Ospedale]),
    link(Osp), 
    %devo fare link con trap exit Osp perché se crepa Osp(che è l'attore che gestisce l'ospedale (morte interna, devo morire io con il codice positivo).
    Cont = spawn(?MODULE, contatti, []), %devo fare monitor perchè può fare exit
    link(Cont),
    %devo fare monitor Cont perché se crepa Cont(che è l'attore che gestisce i contatti (morte esterna), devo morire io con il codice quarantena)
    Vis = spawn(?MODULE, richiesta_luoghi_prima_volta, [Cont]),
    link(Vis),
    %Vis è l'attore che gestisce le visite, lo monitoriamo in modo tale che se crepa utente crepa anche visita, se crepa visita, viene catturata la morte e respawnato
    Luog = spawn(?MODULE, luogo, [Server, Vis, []]),
    link(Luog),
    io:format("L'utente è formato da i seguenti attori:~nOsp=~p~nCont=~p~nVis=~p~nLuog=~p~n", [Osp, Cont, Vis, Luog]),
    receive
        {'EXIT', Osp, positive} -> exit(positive);
        {'EXIT', _, positive} -> exit(quarantena);
        {'EXIT', _, quarantena} -> exit(quarantena);
        {'EXIT', _, REASON} -> 
            io:format('Esco per un errore non catturato. Sono: ~p. Motivo:~p~n', [self(), REASON])
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
        _ -> test(Ospedale)
	end.


%ATTORE Cont
contatti() ->
    receive
        {contact,Pid} -> %l'altro endpoint del protocollo è in luoghi
            link(Pid),
			io:format("L'utente ~p è entrato in contatto con ~p~n",[self(),Pid]),
            contatti()
	end.
	

%ROOT ATTORE Vis
richiesta_luoghi_prima_volta(Cont)->
    process_flag(trap_exit, true),
	receive
		{nuovaLista, L} -> visita_luoghi(L, Cont);
        {'EXIT', Pid, quarantena} -> 
            io:format('Dovrei morire di rimbalzo per quarantena, sono ~p~n', [self()]),
            exit(quarantena);
        {'EXIT', Pid, positive} -> 
            io:format('Dovrei morire di rimbalzo perché sono positivo, sono ~p~n', [self()]),
            exit(positive)
	end.


%ATTORE Vis	
richiesta_luoghi_ricorsiva(ListaAttuale, Cont)->
	receive
		{nuovaLista, L} -> visita_luoghi(L, Cont);
        {'EXIT', Pid, positive} -> 
            io:format('Dovrei morire di rimbalzo perché sono positivo, sono ~p~n', [self()]),
            exit(positive);
        {'EXIT', Pid, quarantena} -> 
            io:format('Dovrei morire di rimbalzo per quarantena, sono ~p~n', [self()]),
            exit(quarantena)
	after timer:seconds(uniform:rand(3-5)) -> visita_luoghi(ListaAttuale, Cont)
	end.


%ATTORE Vis
visita_luoghi(List,Pid)->
	case List of
		[] -> richiesta_luoghi_prima_volta(Pid);
		_ -> 
			N = rand:uniform(length(List)), %numero casuale per scegliere luogo
			Luogo = lists:nth(N, List), %prendo il luogo scelto alla riga precedente
            Ref = make_ref(),
			Luogo ! {begin_visit, Pid, Ref}, %inizio la visita del luogo usando il Pid di contatti
            io:format('Inizio la visita, sono: ~p~n', [self()]),
            receive
                {'EXIT', Pid, quarantena} -> 
                    Luogo ! {end_visit, Pid, Ref},
                    io:format('Finisco la visita per quarantena, sono: ~p~n', [self()]),
                    exit(quarantena);
                {'EXIT', Pid, positivo} -> 
                    Luogo ! {end_visit, Pid, Ref},
                    io:format('Finisco la visita perché sono positivo, sono: ~p~n', [self()]),
                    exit(positivo)
            after timer:seconds(rand:uniform(5,10)) ->
    		    Luogo ! {end_visit, Pid, Ref}, %termino la visita usando sempre il Pid di contatti
                io:format('Finisco la visita, sono: ~p~n', [self()]),
    		    richiesta_luoghi_ricorsiva(List, Pid)
            end
    end.
    
    
%ROOT Attore Luog
luogo(Server,Vis,Luoghi) ->
	Server ! {get_places, self()}, %richiede la lista dei luoghi al server
	L = receive 
		{places,PidList} -> raggiungi3El(Luoghi,PidList--Luoghi) %costruisco la lista attuale dei luoghi
	end,
    Vis ! {nuovaLista, L}, %e la mando a Vis 
    
    %quando il luogo muore, va richiamata la funzione luogo sulla lista meno il luogo morto
    receive
        {'DOWN', _, process, PidLuogo, REASON} -> 
            io:format("Luogo ~p è morto per la ragione:~p~n", [PidLuogo, REASON]),
            luogo(Server, Vis, Luoghi--[PidLuogo])
    after timer:seconds(10) -> luogo(Server, Vis, Luoghi)
    end.
        

%Attore Luog
raggiungi3El(ListaAttuale, ListaServerSenzaRip)->
    case length(ListaAttuale) < 3 of %controllo che la lista attuale abbia meno di 3 luoghi
        true -> 
        		case ListaServerSenzaRip of
        			[] -> ListaAttuale;
        			_ -> L = aggiungiEl(ListaAttuale, ListaServerSenzaRip),
						 raggiungi3El(L, ListaServerSenzaRip--L)
                end; 
        		%in caso positivo aggiungo un altro elemento alla lista attuale e richiamo la funzione fiché non arriva a 3 elementi
        false -> ListaAttuale 
                 %se ha tre o più elementi, restituisco la lista attuale
    end. 
	
%Attore Luog
aggiungiEl(ListaAttuale, ListaServerSenzaRip)->
    N = rand:uniform(length(ListaServerSenzaRip)), %scelgo in modo casuale un elemento di quelli nuovi
    Luogo = lists:nth(N, ListaServerSenzaRip), %seleziono l'elemento scelto alla riga precedente

    %va monitorato il luogo per sapere quando crepa.
    monitor(process, Luogo),
    ListaAttuale++[Luogo]. %appendo l'elemento alla lista attuale
    







    


