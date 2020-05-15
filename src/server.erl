-module(server).
-export([start/0, init_server/1, sleep/1]).

sleep(T) ->
  receive after T -> ok end.

loop(L) ->
  receive
    {new_place, PID} ->
      %io:format("[Server] Received new_place from ~p ~n", [PID]),
      %io:format("[Server] Nuovo place attivo: ~p ~n", [Msg]),
      case lists:member(PID, L) of
        true -> loop(L);
        false ->
          monitor(process, PID),
          loop([ PID | L ])
      end;
  % DOWN - un luogo monitorato muore
    {_, _, process, Pid, Reason} ->
      io:format("[Server] Process ~p died with reason ~p ~n", [Pid, Reason]),
%%      TODO: use the utility function set_subtract
      loop(lists:delete(Pid, L));
    {get_places, PID} ->
      %io:format("[Server] Received request get_places from User ~p ~n", [PID]),
      PID ! {places, L}, % L = lista dei Pid dei luoghi attivi
      loop(L);
    {'EXIT', Sender, R} ->
      %io:format("[Server] ~p received exit from ~p with: ~p~n", [self(), Sender, R]),
      loop(L);
    Msg -> 
      io:format("Messaggio ricevuto~p~n",[Msg]),
      loop(L)
  end.

init_server(L) ->
  process_flag(trap_exit, true),
  loop(L).

start() ->
  global:register_name(server, self()),
  io:format("Io sono il server~n",[]),
  init_server([]).