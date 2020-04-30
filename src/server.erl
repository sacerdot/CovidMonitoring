-module(server).
-export([main/0, init/1, luogo/0, sleep/1]).

sleep(T) ->
  receive after T -> ok end.

init(L) ->
  io:format("Actual places list: ~p ~n", [L]),
  receive
    {new_place, PID} ->
      io:format("Received new_palce from ~p ~n", [PID]),
      monitor(process, PID),
      init([ PID | L ]);
    {_, _, process, Pid, Reason} ->
      io:format("Process ~p died with reason ~p ~n", [Pid, Reason]),
      init(lists:delete(Pid, L))
  end.

luogo() ->
  global:send(server, {new_place, self()}) ,
  sleep(5000),
  exit (ciccio).

main() ->
  L = [],
  H = spawn(?MODULE, init, [L]),
  global:register_name(server, H),
  L1 = spawn(?MODULE, luogo, []),
%%  io:format("~p Luogo 1 ~n", [L1]),
  L2 = spawn(?MODULE, luogo, []),
%%  io:format("~p Luogo 2 ~n", [L2]),
  sleep(1000),
  exit(L2,kill).

