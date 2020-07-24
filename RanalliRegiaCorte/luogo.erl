-module(luogo).
-export([start/0, ciclo_di_vita/1, mantenimento_topologia/1, mantieni_lista_visitatori/4]).

%Attore principale che si occupa del protocollo di inizializzazione
luogo()->
	Server=global:whereis_name(server),
	link(Server),
	io:format("Io sono il luogo ~p~n", [self()]),
	Server ! {new_place, self()},
	process_flag(trap_exit, true),
	Gestore_ciclo_di_vita=spawn_link(?MODULE, ciclo_di_vita, [self()]),	%Attore che si occupa del ciclo di vita
	Gestore_rilevamento_contatti=spawn_link(?MODULE, mantenimento_topologia, [self()]), %Attore che si occupa del protocollo di rilevamento dei contatti
	Gestore_lista=spawn_link(?MODULE, mantieni_lista_visitatori, [[], self(), Gestore_rilevamento_contatti, Gestore_ciclo_di_vita]),	%Attore che si occupa del protocollo di visita dei luoghi
	gestione_messaggi(Gestore_ciclo_di_vita, Gestore_rilevamento_contatti, Gestore_lista, self())
	.
	
	
gestione_messaggi(Gestore_ciclo_di_vita, Gestore_rilevamento_contatti, Gestore_lista, PidLuogo)->
	Server=global:whereis_name(server),
	receive
		%Gestione messaggi delle visite
		{begin_visit, PidVisitatore, Ref}->	Gestore_lista ! {aggiungi_utente, PidVisitatore, Ref},
											gestione_messaggi(Gestore_ciclo_di_vita, Gestore_rilevamento_contatti, Gestore_lista, PidLuogo);
		{end_visit, PidVisitatore, Ref}-> Gestore_lista ! {elimina_utente, PidVisitatore, Ref},
										  gestione_messaggi(Gestore_ciclo_di_vita, Gestore_rilevamento_contatti, Gestore_lista, PidLuogo);
		%Gestione di messaggi di fallimento
		{'EXIT', Gestore_ciclo_di_vita, normal}-> erlang:exit(normal);
		{'EXIT', Gestore_ciclo_di_vita, _}-> NuovoGCV=spawn_link(?MODULE, ciclo_di_vita, [self()]), 
											 Gestore_lista ! {aggiornaPid, pidGCV, NuovoGCV},
											 gestione_messaggi(NuovoGCV, Gestore_rilevamento_contatti, Gestore_lista, PidLuogo);
		{'EXIT', Gestore_rilevamento_contatti, _}-> NuovoGRC=spawn_link(?MODULE, mantenimento_topologia, [self()]), 
													Gestore_lista ! {aggiornaPid, pidGRC, NuovoGRC},
													gestione_messaggi(Gestore_ciclo_di_vita, NuovoGRC, Gestore_lista, PidLuogo);
		{'EXIT', Gestore_lista, _}-> NuovoGL=spawn_link(?MODULE, mantieni_lista_visitatori, [[], self(), Gestore_rilevamento_contatti, Gestore_ciclo_di_vita]),	
									 gestione_messaggi(Gestore_ciclo_di_vita, Gestore_rilevamento_contatti, NuovoGL, PidLuogo);
		{'EXIT', Server, Reason}-> io:format("IL SERVER È MORTO, MUOIO ANCHE IO! MOTIVO DEL FALLIMENTO:~p ~n", [Reason]),
								   exit(Reason)
	end.


	
%Attore che si occupa del protocollo della visita dei luoghi
mantieni_lista_visitatori(ListaVisitatori, PidLuogo, Gestore_rilevamento_contatti, Gestore_ciclo_di_vita)->
	receive
		{aggiornaPid, X, PidNuovo}-> case X of
											pidGCV->mantieni_lista_visitatori(ListaVisitatori, PidLuogo, Gestore_rilevamento_contatti, PidNuovo);
											pidGRC->mantieni_lista_visitatori(ListaVisitatori, PidLuogo, PidNuovo, Gestore_ciclo_di_vita)
									end;

		{aggiungi_utente, PidUtente, Ref}-> case lists:member({PidUtente,Ref}, ListaVisitatori) of
												true-> io:format("L'utente ~p è già in questo luogo", [PidUtente]),
														mantieni_lista_visitatori(ListaVisitatori, PidLuogo, Gestore_rilevamento_contatti, Gestore_ciclo_di_vita);
												false-> printEntrata(PidLuogo, PidUtente, ListaVisitatori),
														Gestore_rilevamento_contatti ! {PidUtente, self()},
														Gestore_ciclo_di_vita ! {nuova_visita},
														mantieni_lista_visitatori(ListaVisitatori++[{PidUtente, Ref}], PidLuogo, Gestore_rilevamento_contatti, Gestore_ciclo_di_vita)
											end;			
		{elimina_utente, PidUtente, Ref}-> case lists:member({PidUtente, Ref}, ListaVisitatori) of
												true -> printUscita(PidLuogo, PidUtente, ListaVisitatori),
														mantieni_lista_visitatori(ListaVisitatori--[{PidUtente, Ref}], PidLuogo, Gestore_rilevamento_contatti, Gestore_ciclo_di_vita);
												false-> io:format("Mi dispiace ma non sei in questo luogo"),
														mantieni_lista_visitatori(ListaVisitatori, PidLuogo, Gestore_rilevamento_contatti, Gestore_ciclo_di_vita)
											end;
		{richiesta_visitatori, PidRichiedente}->PidRichiedente ! {risposta_visitatori, ListaVisitatori},
												mantieni_lista_visitatori(ListaVisitatori, PidLuogo, Gestore_rilevamento_contatti, Gestore_ciclo_di_vita)
	end.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



%Attore che si occupa del protocollo di rilevamento dei contatti
mantenimento_topologia(PidLuogo)->
	receive
		{PidUtente, Gestore_lista}-> ListaVisitatori=ottieni_lista(Gestore_lista),
									  case length(ListaVisitatori)>=1 of
											true-> calcola_incontri(ListaVisitatori, PidUtente),
												   mantenimento_topologia(PidLuogo);
													
											false-> mantenimento_topologia(PidLuogo)
									  end
	end.				  
					 	
	
calcola_incontri([], _)->ok;							
calcola_incontri([{PidVisitatore,_}|Tail], PidVisitatore)->calcola_incontri(Tail, PidVisitatore);
calcola_incontri([{Pid,_}|Tail], PidVisitatore)->
	Prob= rand:uniform(100),
	case Prob =<25 of
		false -> PidVisitatore ! {contact, Pid},
				Pid ! {contact, PidVisitatore},
				calcola_incontri(Tail, PidVisitatore);
		true ->calcola_incontri(Tail, PidVisitatore)
	end.	 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%




%Attore che si occupa del ciclo di vita
ciclo_di_vita(PidLuogo)->
	receive
		{nuova_visita}-> Prob= rand:uniform(10),
						 case Prob of
							1 -> io:format("[~p]: IL LUOGO CHIUDE ~n~n", [PidLuogo]),
								 erlang:exit(normal);
							_ -> ciclo_di_vita(PidLuogo)

						end	
	end.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%Funzioni ausiliarie
ottieni_lista(Gestore_lista)->
	Gestore_lista ! {richiesta_visitatori, self()},
	receive
		{risposta_visitatori, ListaOttenuta}->ListaOttenuta
	end.	


repeat(X,N) ->
    lists:flatten(lists:duplicate(N,X)).

printEntrata(PidLuogo, PidUtente, ListaVisitatori)->
		L=[Pid || {Pid, _}<-ListaVisitatori],
		A=repeat("-", 11),
		io:format(A++"[Luogo ~p]"++A++A++"~nUtente entrante: ~p -> Lista visitatori: ~p ~n"++repeat("-", 49)++"~n~n", [PidLuogo, PidUtente, L]).


printUscita(PidLuogo, PidUtente, ListaVisitatori)->
		L=[Pid || {Pid, _}<-ListaVisitatori, Pid/=PidUtente],
		A=repeat("-", 11),
		io:format(A++"[Luogo ~p]"++A++A++"~nLista visitatori: ~p -> Utente uscente: ~p~n"++repeat("-", 49)++"~n~n", [PidLuogo, L, PidUtente]).


start()->
  [spawn(fun luogo/0) || _ <- lists:seq(1,5)].