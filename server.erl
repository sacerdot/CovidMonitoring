-module(server).
-export([server_init/0, server/1]).



server(Places) ->
    receive
        {new_place, Pid_Place} ->
            io:format("New Place ~p~n",[Pid_Place]),
            monitor(process,Pid_Place),
            %Pid_Place ! {okay},                  %no recive in places
            server([Pid_Place|Places]);

        {get_places, Pid_User} ->
            Pid_User ! {places, Places},
            server(Places);

        {'DOWN', _ , process, Pid, Reason } -> %{'DOWN', Reference, process, Pid, Reason} ->
            io:format("~p e' morto e questo è il messaggio di monitor : ~p ~n", [Pid, Reason]),
            io:format("~p luoghi rimanenti ~n", [length(Places) - 1]),

            server(Places -- [Pid]);

        {'EXIT',Pid, Reason} -> %il trattino sarebbe Pid
            io:format("EXIT in server Pid ~p Reason ~p~n", [Pid, Reason]),
            case Reason of
                X when X =:= 'positive'; X =:= 'normal';  X =:= 'quarantena' -> ok;
                _ -> exit(Reason) %nel caso in cui qualuno a cui siamo linkati termini per un'altra ragione, anche noi terminiamo con la stessa reason
            end,
            server(Places)
    end.

server_init() ->
    %ServerPid = spawn(?MODULE, server, [[]]),
    ServerPid=spawn(fun() -> process_flag(trap_exit, true), server([]) end),
    global:register_name(server,ServerPid),
    io:format("Pid Server ~p~n", [ServerPid]).
