-module(server).
-export([start/0]).
-import(utils, [sleep/1, set_subtract/2]).

loop(L, NumeroUtenti) ->
  case NumeroUtenti of
    10 -> 
      io:format("TUTTI GLI UTENTI SONO MORTI!!!!~n"),
      exit(no_more_user_alive);
    _ ->
      receive
        {new_place, PID} ->
          %io:format("[Server] Received new_place from ~p ~n", [PID]),
          %io:format("[Server] Nuovo place attivo: ~p ~n", [Msg]),
          case lists:member(PID, L) of
            true -> loop(L, NumeroUtenti);
            false ->
              monitor(process, PID),
              loop([ PID | L ], NumeroUtenti)
          end;
        % DOWN message from a monitored place died
        {_, _, process, Pid, Reason} ->
          io:format("[Server] Process ~p died with reason ~p ~n", [Pid, Reason]),
          loop(set_subtract(L, [Pid]), NumeroUtenti);
        {get_places, PID} ->
          %io:format("[Server] Received request get_places from User ~p ~n", [PID]),
          PID ! {places, L}, % L = lista dei Pid dei luoghi attivi
          loop(L, NumeroUtenti);
        {'EXIT', _, _} ->
          %io:format("[Server] ~p received exit from ~p with: ~p~n", [self(), Sender, R]),
          loop(L, NumeroUtenti + 1);
        Msg -> 
          % Check message from other actors
          io:format("Messaggio ricevuto~p~n",[Msg]),
          loop(L, NumeroUtenti)
      end
  end.

init_server(L) ->
  process_flag(trap_exit, true),
  loop(L, 0).

start() ->
  global:register_name(server, self()),
  io:format("Io sono il server~n",[]),
  init_server([]).