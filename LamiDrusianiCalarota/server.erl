-module(server).
-export([start/0]).

start() ->
    spawn(fun server/0).

% Creazione Server
server() ->
    global:register_name(server, self()),
    process_flag(trap_exit, true),
    io:format("Io sono il server~n", []),
    topologia([]).
    
% Protocollo per gestione richieste
topologia(Luoghi) ->
    receive
        {new_place, Pid} -> io:format("Registrazione luogo ~p~n",[Pid]), topologia(Luoghi++[Pid]);
        {'EXIT', Pid, normal} -> io:format("Chiusura luogo ~p~n",[Pid]), topologia(Luoghi--[Pid]);
        {get_places, Pid} -> io:format("Richiesta luoghi al server=~p da utente con Luog=~p~n",[self(), Pid]), Pid ! {places, Luoghi}, topologia(Luoghi)
    end.
