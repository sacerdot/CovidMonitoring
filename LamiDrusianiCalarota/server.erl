-module(server).
-export([start/0]).


start() ->
	global:register_name(server, self()),
	process_flag(trap_exit, true),
	io:format("Io sono il server~n", []),
	topologia([]).
	

topologia(Luoghi) ->
	receive
		{new_place, Pid} -> io:format("Registrazione luogo ~p~n",[Pid]), topologia(Luoghi++Pid);
		{'EXIT', Pid, ho_chiuso} -> io:format("Chiusura luogo ~p~n",[Pid]), topologia(lists:delete(Pid, Luoghi));
		{get_places, Pid} -> io:format("Richiesta luoghi da ~p~n",[Pid]), Pid ! {places, Luoghi}, topologia(Luoghi)
	end.


	

