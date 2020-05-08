-module(server).
-export([main/0, init_server/1, sleep/1]).

sleep(T) ->
  receive after T -> ok end.

init_server(L) ->
  receive
    {new_place, PID} ->
      %io:format("[Server] Received new_place from ~p ~n", [PID]),
      %io:format("[Server] Nuovo place attivo: ~p ~n", [Msg]),
      case lists:member(PID, L) of
        true -> init_server(L);
        false -> 
          monitor(process, PID),
          init_server([ PID | L ]) 
      end;
      % DOWN - un luogo monitorato muore
    {_, _, process, Pid, Reason} ->
      io:format("Process ~p died with reason ~p ~n", [Pid, Reason]),
%%      TODO: use the utility function set_subtract
      init_server(lists:delete(Pid, L));
    {get_places, PID} ->
      PID ! {places, L}, % L = lista dei Pid dei luoghi attivi
      init_server(L)
  end.

% test
% luogo() ->
%   global:send(server, {new_place, self()}) ,
%   sleep(rand:uniform(5000)),
%   exit (ciccio).

% luogo2() ->
%   global:send(server, {new_place, self()}) ,
%   global:send(server, {new_place, self()}) ,
%   sleep(rand:uniform(5000)),
%   exit (ciccio).

main() ->
  Init = spawn(?MODULE, init, [[]]),
  global:register_name(server, Init).
  %spawn(?MODULE, luogo, []),
  %L2 = spawn(?MODULE, luogo2, []),
  %L3 = spawn(?MODULE, luogo, []),
  %spawn(?MODULE, luogo2, []),
  %spawn(?MODULE, luogo, []),
  %sleep(1000),
  %exit(L2,kill),
  %exit(L3, kill).

