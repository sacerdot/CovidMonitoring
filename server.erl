-module(server).
-export([server_init/0, server/1]).

death_of_user([], _) -> ok;
death_of_user([H|T], PidU) -> H ! {death_of_user, PidU}, death_of_user(T, PidU).

server(Places) ->
    receive
        {new_place, Pid_Place} ->
            io:format("New Place ~p~n",[Pid_Place]),
            %monitor(process,Pid_Place),
            %Pid_Place ! {okay},                  %no recive in places
            server([Pid_Place|Places]);

        % {'DOWN', _ , process, Pid, Reason } -> %{'DOWN', Reference, process, Pid, Reason} ->
        %     io:format("~p e' morto e questo è il messaggio di monitor : ~p ~n", [Pid, Reason]),
        %     server(Places -- [Pid]);

        {'EXIT',Pid, Reason} -> %vedere se bisogna trrattare morete di utenti in modo diverso
            io:format("Process received exit ~p ~p.~n",[Pid, Reason]),
            case Reason of
                positive -> death_of_user(Places, Pid);
                _ -> ok
            end,
            server(Places -- [Pid]);

        {get_places, Pid_User} ->
            Pid_User ! {places, Places},
            server(Places)

        % {new_usr, Pid_User} ->
        %       io:format("New User ~p~n",[Pid_User]),
        %       %monitor(process,Pid_User),
        %       %Pid_User ! {okay},             %no rec in users
        %       server(Places)
    end.

server_init() ->
    %ServerPid = spawn(?MODULE, server, [[]]),
    ServerPid=spawn(fun() -> process_flag(trap_exit, true), server([]) end),
    global:register_name(server,ServerPid),
    io:format("Pid Server ~p~n", [ServerPid]).
