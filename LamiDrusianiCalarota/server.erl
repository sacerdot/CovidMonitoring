-module(server).
-export([start/0, server/0]).

start() ->
    spawn(?MODULE, server, []).

server() ->
	global:register_name(server, self()),
	process_flag(trap_exit, true),
	io:format("Io sono il server~n", []),
	topologia([]).
	

topologia(Luoghi) ->
	receive
		{new_place, Pid} -> io:format("Registrazione luogo ~p~n",[Pid]), topologia(Luoghi++[Pid]);
		{'EXIT', Pid, normal} -> io:format("Chiusura luogo ~p~n",[Pid]), topologia(Luoghi--[Pid]);
		{get_places, Pid} -> io:format("Richiesta luoghi da ~p~n",[Pid]), Pid ! {places, Luoghi}, topologia(Luoghi)
	end.
