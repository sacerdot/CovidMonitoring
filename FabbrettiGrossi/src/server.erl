-module(server).
-export([start/0]).


update_places(PIDLIST) ->
  receive
      
    % INIT PROTOCOL/1: keeps and monitors a place list
    {new_place, PID_LUOGO} ->
      % monitor it
      Res = erlang:monitor(process, PID_LUOGO),
      io:format("~p~n", [Res]),
      % add to the place list
      update_places([PID_LUOGO | PIDLIST]);

    % INIT PROTOCOL/2: react to a place exit
    {'DOWN', Ref, process, PID_LUOGO, Reason} ->
      io:format("Sto per rimuovere ~p dalla lista dei luoghi~n", [PID_LUOGO]),
      % remove the place from list
      % update the place list
      update_places(PIDLIST -- [PID_LUOGO]);

    % TOPOLOGY PROTOCOL
    {get_places, PID} ->
      PID ! {places, PIDLIST},
      update_places(PIDLIST)
  end.


start() ->
  global:register_name(server,self()),
  io:format("Io sono il server~n",[]),
  % set trap flag! The places and users processes are linked... link are bidirectional. WARNING)
  process_flag(trap_exit, true),
  update_places([]).
