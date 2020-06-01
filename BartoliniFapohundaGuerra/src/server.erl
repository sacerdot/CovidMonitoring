-module(server).
-export([start/0]).
-import(utils, [sleep/1, set_subtract/2]).

%%%%%%%%%%%%%%%%%%%%%%%%%%% PROTOCOLLO DI INIZIALIZZAZIONE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
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
    {'DOWN', _, process, Pid, Reason} ->
      io:format("[Server] Luogo monitorato ~p morto per ~p ~n", [Pid, Reason]),
      loop(set_subtract(L, [Pid]));
    {get_places, PID} ->
      PID ! {places, L}, % L = lista dei Pid dei luoghi attivi
      loop(L);
  % Msg exit from a user died
    {'EXIT', _, _} -> loop(L);
    {ciao, da, luogo, Pid} -> io:format("[Server] Benvenuto luogo ~p~n", [Pid]), loop(L);
    {ciao, da, utente, Pid} -> io:format("[Server] Benvenuto utente ~p~n", [Pid]), loop(L);
    {ciao, da, ospedale} -> io:format("[Server] Benvenuto ospedale ~n"), loop(L);
    Msg ->
      io:format("[Server] Messaggio non gestito ~p~n", [Msg]),
      loop(L)
  end.

init_server(L) ->
  process_flag(trap_exit, true),
  loop(L).

%%%%%%%%%%%%%%%%%%%%%%%%%%% PROTOCOLLO DI MANTENIMENTO DELLA TOPOLOGIA %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
start() ->
  global:register_name(server, self()),
  io:format("Io sono il server~n", []),
  init_server([]).