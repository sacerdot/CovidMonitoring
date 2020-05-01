-module(server).
-export([main/0, init/1, luogo/0, luogo2/0, sleep/1]).

sleep(T) ->
  receive after T -> ok end.

init(L) ->
  io:format("[Server] Actual places list: ~p ~n", [L]),
  receive
    {new_place, PID} ->
      io:format("[Server] Received new_place from ~p ~n", [PID]),
      case lists:member(PID, L) of
        true -> init(L);
        false -> 
          monitor(process, PID),
          init([ PID | L ])
      end;
    {_, _, process, Pid, Reason} ->
      io:format("Process ~p died with reason ~p ~n", [Pid, Reason]),
      init(lists:delete(Pid, L))
      % can we use -- instead delete? 
  end.

% test
luogo() ->
  global:send(server, {new_place, self()}) ,
  sleep(2000),
  exit (ciccio).

luogo2() ->
  global:send(server, {new_place, self()}) ,
  global:send(server, {new_place, self()}) ,
  sleep(2000),
  exit (ciccio).

main() ->
  L = [],
  H = spawn(?MODULE, init, [L]),
  global:register_name(server, H),
  L1 = spawn(?MODULE, luogo, []),
%%  io:format("~p Luogo 1 ~n", [L1]),
  L2 = spawn(?MODULE, luogo2, []),
%%  io:format("~p Luogo 2 ~n", [L2]),
  sleep(1000),
  exit(L2,kill).

