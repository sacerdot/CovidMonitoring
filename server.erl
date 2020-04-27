-module(server).
-export([server_init/0, server/1]).

server(Places) ->
    receive
        {new_place, Pid_Place} -> 
            io:format("New Place ~p~n",[Pid_Place]),
            monitor(process,Pid_Place),
            Pid_Place ! {okay},
            server([Pid_Place|Places]);
        
        {'DOWN', _ , process, Pid, _ } -> %{'DOWN', Reference, process, Pid, Reason} ->
            io:format("~p e' morto~n", [Pid]),
            server(Places -- [Pid]);
        
        {get_places, Pid_User} ->
            Pid_User ! {places, Places},
            server(Places)
    end.

server_init() ->
    ServerPid = spawn(?MODULE, server, [[]]),
    global:register_name(server,ServerPid).