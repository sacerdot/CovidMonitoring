-module(utente).
-export([start/0, mantenimento_topologia/2, visita_luoghi/3, test_utenti/2, mantieni_lista_luoghi/2, aggiorna_lista/3]).

%Protocollo di mantenimento della topologia (lett. a) e creazione attori
topologia()->
	Server=global:whereis_name(server),
	link(Server),
	io:format("Io sono l'utente ~p~n", [self()]),
	Gestore_test=spawn_link(?MODULE, test_utenti, [[], self()]),	%Attore che si occupa del protocollo di test
	Gestore_lista=spawn_link(?MODULE, mantieni_lista_luoghi, [[], self()]),	%Attore che si occupa del protocollo di mantenimento topologia (lett. b, d)
	Gestore_luoghi=spawn_link(?MODULE, mantenimento_topologia, [self(), Gestore_lista]),	%Attore che si occupa del protocollo di mantenimento topologia (lett. c)
	Gestore_visite=spawn_link(?MODULE, visita_luoghi, [[], self(), Gestore_lista]),		%Attore che si occupa del protocollo di visita dei luoghi
	gestione_messaggi(Gestore_luoghi, Gestore_test, Gestore_visite, Gestore_lista, self())
	.


%L'attore principale fungerà da dispatcher: si occuperà di ricevere le richieste e ridistribuirle
gestione_messaggi(Gestore_luoghi, Gestore_test, Gestore_visite, Gestore_lista, PidUtente)->
	process_flag(trap_exit, true),
	Server=global:whereis_name(server),
	receive
		%Gestione messaggi di routine
		{places, PIDLIST}-> spawn_link(?MODULE, aggiorna_lista, [PIDLIST, self(), Gestore_lista]),	%Attore ausiliario
							gestione_messaggi(Gestore_luoghi, Gestore_test, Gestore_visite, Gestore_lista, self());
		{contact, PID}->io:format("Utente ~p -> sei entrato in contatto con utente ~p~n", [self(), PID]), 
						link(PID),
						gestione_messaggi(Gestore_luoghi, Gestore_test, Gestore_visite, Gestore_lista, self());
		%Gestione messaggi di testing
		{positive}->Gestore_visite! {esci, fallimento},
					printPositivita(PidUtente, "POSITIVO"),
					sleep(5),
					exit(positivo);
		{negative}-> printPositivita(PidUtente, "NEGATIVO"),
					gestione_messaggi(Gestore_luoghi, Gestore_test, Gestore_visite, Gestore_lista, self());
		%Gestione di messaggi di fallimento
		{'EXIT', _PID, X} when X=:=quarantena; X=:=positivo-> Gestore_visite! {esci, fallimento},
															  printPositivita(PidUtente, "POSITIVO, entro in quarantena"),
															  erlang:exit(quarantena);
		{'EXIT', Gestore_luoghi, _}-> PidNuovo=spawn_link(?MODULE, mantenimento_topologia, [self(), Gestore_lista]),
									  gestione_messaggi(PidNuovo, Gestore_test, Gestore_visite, Gestore_lista, PidUtente);
		{'EXIT', Gestore_test, _}-> PidNuovo=spawn_link(?MODULE, test_utenti, [[], PidUtente]),
									gestione_messaggi(Gestore_luoghi, PidNuovo, Gestore_visite, Gestore_lista, PidUtente);
		{'EXIT', Gestore_visite, _}->PidNuovo=spawn_link(?MODULE, visita_luoghi, [[], self(), Gestore_lista]),
									 gestione_messaggi(Gestore_luoghi, Gestore_test, PidNuovo, Gestore_lista, PidUtente);
		{'EXIT', Gestore_lista, _}-> PidNuovo=spawn_link(?MODULE, mantieni_lista_luoghi, [[], self()]),
									 Gestore_luoghi ! {aggiornaPid, PidNuovo}, 
									 Gestore_visite ! {aggiornaPid, PidNuovo},	
									 gestione_messaggi(Gestore_luoghi, Gestore_test, PidNuovo, Gestore_lista, PidUtente);
		{'EXIT', Server, Reason}-> io:format("IL SERVER È MORTO, MUOIO ANCHE IO! MOTIVO DEL FALLIMENTO:~p ~n", [Reason]), exit(Reason)
	end.


%Attore ausiliario che si occupa di confrontare la lista ottenuta dal server con la lista
%attuale dell'utente e, nel caso in cui quest'ultima fosse minore di tre, di estrarre casualmente
%i luoghi per poter portare la lista a 3
aggiorna_lista(ListaOttenutaDalServer, PidUtente, Gestore_lista)->
	{ListaPersonale, _}=ottieni_lista(Gestore_lista),
	ListaSottratta=ListaOttenutaDalServer-- ListaPersonale,
	case length(ListaSottratta)=:=0 of
		true-> ok;
		false-> case length(ListaPersonale)<3 of
					true ->N1=rand:uniform(length(ListaSottratta)),
						   Elem=lists:nth(N1, ListaSottratta), 
						   Gestore_lista ! {aggiorna_lista, Elem},
						   aggiorna_lista(ListaOttenutaDalServer, PidUtente, Gestore_lista);
					false ->exit(normal)
				end
	end.			
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%			



	
%Attore che si occupa del protocollo di visita dei luoghi
visita_luoghi(Lista, PidUtente, Gestore_lista)->
	{ListaOttenuta, PidEventualmenteNuovo}=ottieni_lista(Gestore_lista), 
	case length(ListaOttenuta)>0 of
		true->inizio_fineVisita(ListaOttenuta, PidUtente);
		false->ok
	end,
	N=rand:uniform(2)+3,
	sleep(N),
	visita_luoghi(Lista, PidUtente, PidEventualmenteNuovo)
	.

inizio_fineVisita(ListaLuoghi, PidVisitatore)->
	N=rand:uniform(length(ListaLuoghi)),
	LuogoDaVisitare=lists:nth(N, ListaLuoghi),
	Ref=make_ref(),
	LuogoDaVisitare ! {begin_visit, PidVisitatore, Ref},
	printEntrata(PidVisitatore, LuogoDaVisitare),
	DurataVisita=rand:uniform(5)+5,	
	receive 
	{esci, fallimento}->	%Protocollo di test (lett. c)
						printUscita(PidVisitatore, LuogoDaVisitare, "perchè positivo"),
						LuogoDaVisitare ! {end_visit, PidVisitatore, Ref},
						exit(positive)
	after DurataVisita *1000 ->
						printUscita(PidVisitatore, LuogoDaVisitare, ""),
						LuogoDaVisitare ! {end_visit, PidVisitatore, Ref}
	end.	
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



%Attore che si occupa del protocollo di test
test_utenti(Lista, PidUtente)->
	N=rand:uniform(4),
	case N of
		1-> global:send(hospital, {test_me, PidUtente});
		_->ok
	end,
	sleep(30),
	test_utenti(Lista, PidUtente).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



%Attore che si occupa del protocollo di mantenimento della topologia (lett. b, d)
mantieni_lista_luoghi(Lista, PidUtente)->
	receive
		{aggiorna_lista, Elem} -> monitor(process, Elem), mantieni_lista_luoghi(Lista++[Elem], PidUtente);
		{richiestaLuoghi, PID} -> PID ! {risposta_luoghi, Lista}, mantieni_lista_luoghi(Lista, PidUtente);
		{'DOWN', _Ref, process, PIDmorto, _Reason}->global:send(server, {get_places, PidUtente}),
												    mantieni_lista_luoghi(Lista--[PIDmorto], PidUtente)
	end.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



	
%Attore che si occupa del protocollo di mantenimento della topologia (lett. c)
mantenimento_topologia(PidUtente, Gestore_lista)->
	{ListaOttenuta, PidEventualmenteNuovo}=ottieni_lista(Gestore_lista),
	case length(ListaOttenuta)<3 of
		true -> global:send(server, {get_places, PidUtente});
		false -> ok
	end,
	sleep(10),
	mantenimento_topologia(PidUtente, PidEventualmenteNuovo). 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



%Funzioni ausiliarie
ottieni_lista(Gestore_lista)->
	Gestore_lista ! {richiestaLuoghi, self()},
	receive
		{aggiornaPid, PidNuovo}->ottieni_lista(PidNuovo);
		{risposta_luoghi, ListaOttenuta}->{ListaOttenuta, Gestore_lista}
	end
	.

sleep(N)->
	receive
	after N * 1000 ->ok
	end.

repeat(X,N) ->
    lists:flatten(lists:duplicate(N,X)).

printEntrata(PidVisitatore, LuogoDaVisitare)->
	A=repeat("-", 60),
	io:format(A++"~nUtente: [~p] visita Luogo: ~p~n"++A++"~n", [PidVisitatore, LuogoDaVisitare])
	.

printUscita(PidVisitatore, LuogoDaVisitare, B)->
A=repeat("-", 60),
io:format(A++"~nUtente: [~p] abbandona Luogo: ~p "++B++"~n"++A++"~n", [PidVisitatore, LuogoDaVisitare])
.

printPositivita(PidUtente, Risultato)->
A=repeat("=", 60),
io:format(A++"~n[~p]: SONO "++ Risultato++"~n"++A++"~n", [PidUtente])
.

start() ->
  [ spawn(fun topologia/0) || _ <- lists:seq(1,2) ].