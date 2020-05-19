-module(server).
-export([start/0]).


update_places(PIDLIST) ->
    receive
        % INIT PROTOCOL/1: keeps and monitors a place list
        {new_place, PID_LUOGO} ->

            update_places([PID_LUOGO | PIDLIST]);

            % INIT PROTOCOL/2: react to a place exit
        {'EXIT', Pid, normal} ->
            io:format("Sto per rimuovere ~p dalla lista dei luoghi~n", [Pid]),
            update_places(PIDLIST -- [Pid]);
        {'EXIT', Pid, Reason} ->
            io:format("~p exit because ~p~n", [Pid, Reason]),
            update_places(PIDLIST);
            % TOPOLOGY PROTOCOL
        {get_places, PID} ->
            PID ! {places, PIDLIST},
            update_places(PIDLIST)
  end.


start() ->
    global:register_name(server,self()),
    io:format("Io sono il server~n",[]),
    process_flag(trap_exit, true),
    update_places([]).
