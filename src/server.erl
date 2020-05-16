-module(server).
-export([start/0]).
-import(utils, [sleep/1, set_subtract/2]).

loop(L) ->
  receive
    {new_place, PID} ->
      case lists:member(PID, L) of
        true -> loop(L);
        false ->
          monitor(process, PID),
          loop([PID | L])
      end;
    % DOWN message from a monitored place died
    {_, _, process, Pid, Reason} ->
      io:format("[Server] Monitored place ~p died with reason ~p ~n", [Pid, Reason]),
      loop(set_subtract(L, [Pid]));
    {get_places, PID} ->
      PID ! {places, L}, % L = lista dei Pid dei luoghi attivi
      loop(L);
    %msg exit from a user died
    {'EXIT', _, _} ->
      loop(L);
    Msg ->
      io:format("[Server] ~p~n", [Msg]),
      loop(L)
  end.

init_server(L) ->
  process_flag(trap_exit, true),
  loop(L).

start() ->
  global:register_name(server, self()),
  io:format("Io sono il server~n", []),
  init_server([]).