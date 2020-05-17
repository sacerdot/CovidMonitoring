-module(utenti).
-export([start/0,test/1,contatti/0, richiesta_luoghi_prima_volta/1]).

start()-> utente().

utente()->
	Server = global:whereis_name(server),
	Ospedale = global:wheris_name(hospital),
	link(Server),
    Osp = spawn(?MODULE, test, [Ospedale]), 
    %devo fare monitor Osp perché se crepa Osp(che è l'attore che gestisce l'ospedale (morte interna, devo morire io con il codice positivo).
    Cont = spawn(?MODULE, contatti, []), %devo fare monitor perchè può fare exit
    %devo fare monitor Cont perché se crepa Cont(che è l'attore che gestisce i contatti (morte esterna), devo morire io con il codice quarantena)
    Vis = spawn(?MODULE, richiesta_luoghi_prima_volta, [Cont]),
    %Vis è l'attore che gestisce le visite, lo monitoriamo in modo tale che se crepa utente crepa anche visita, se crepa visita, viene catturata la morte e respawnato
    Luog = spawn(?MODULE, luogo, [Server, Vis, []]).
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
	

%ATTORE Vis
richiesta_luoghi_prima_volta(Cont)->
	receive
		{nuovaLista, L} -> visita_luoghi(L, Cont)
	end.
	
	
richiesta_luoghi_ricorsiva(ListaAttuale, Cont)->
	receive
		{nuovaLista, L} -> visita_luoghi(L, Cont)
	after timer:seconds(uniform:rand(3-5)) -> visita_luoghi(ListaAttuale, Cont)
	end.



visita_luoghi(List,Pid)->
	case List of
		[] -> richiesta_luoghi_prima_volta(Pid);
		_ -> 
			N = rand:uniform(length(List)), %numero casuale per scegliere luogo
			Luogo = lists:nth(N, List), %prendo il luogo scelto alla riga precedente
			Luogo ! {begin_visit,Pid,make_ref()}, %inizio la visita del luogo usando il Pid di contatti
    		timer:sleep(timer:second(rand:uniform(5,10))), %durata della visita
    		Luogo ! {end_visit,Pid,make_ref()}, %termino la visita usando sempre il Pid di contatti
    		richiesta_luoghi_ricorsiva(List, Pid)
    end.
    
    
%Attore Luog
luogo(Server,Vis,Luoghi) ->
	Server ! {get_places, self()}, %richiede la lista dei luoghi al server
	L = receive 
		{places,PidList} -> raggiungi3El(Luoghi,PidList--Luoghi) %costruisco la lista attuale dei luoghi
	end,
    Vis ! {nuovaLista, L}, %e la mando a Vis 
    
    %quando il luogo muore, va richiamata la funzione luogo
    %receive monitor 
    
    luogo(Server, Vis, Luoghi). %va fatto solo quando un luogo muore
    	
	
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
	

aggiungiEl(ListaAttuale, ListaServerSenzaRip)->
    N = rand:uniform(length(ListaServerSenzaRip)), %scelgo in modo casuale un elemento di quelli nuovi
    Luogo = lists:nth(N, ListaServerSenzaRip), %seleziono l'elemento scelto alla riga precedente

    %va monitorato il luogo per sapere quando crepa.
    
    ListaAttuale++[Luogo]. %appendo l'elemento alla lista attuale
    







    


