-module(server).
-export([start/0]).


%protocollo di inizializzazione & protocollo di mantenimento topologia (risposte su conoscenza luoghi) 
inizializzazione(LuoghiAttivi)->
	receive
		{new_place, PID} -> io:format("LUOGHI ATTIVI: ~p~n", [LuoghiAttivi++[PID]]),
							inizializzazione(LuoghiAttivi++[PID]);
		{'EXIT', PID, X} when X=:=quarantena; X=:=positivo -> io:format("L'utente ~p è in quarantena/morto~n", [PID]),
															  inizializzazione(LuoghiAttivi);
		{'EXIT', PID, _Reason} -> case lists:member(PID, LuoghiAttivi) of
									true-> io:format("LUOGHI ATTIVI: ~p~n", [LuoghiAttivi--[PID]]),
										   inizializzazione(LuoghiAttivi--[PID]);
									false ->inizializzazione(LuoghiAttivi)
									end;
		{get_places, PID} when length(LuoghiAttivi)/=0->
										PID ! {places, LuoghiAttivi}, inizializzazione(LuoghiAttivi)
	end.


%protocollo di mantenimento topologia (fase di registrazione)
start() ->
  global:register_name(server,self()),
  io:format("Io sono il server~n",[]),
  process_flag(trap_exit, true),
  inizializzazione([]).
 