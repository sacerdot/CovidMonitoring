-module(server).
-export([main/0, init/1, luogo/0, sleep/1]).

sleep(T) ->
  receive after T -> ok end.

init(L) ->
  receive
    {new_place, PID} ->
      io:format("msg from ~p ~n", [PID]),
      monitor(process, PID),
      init([ PID | L ]);
    Msg = {DOWN, Reference, process, Pid, Reason} ->
      io:format("~p monitor1 ~n", [Msg]),
      init(L);
    M = _ ->
      io:format("~p monitor2 ~n", [M])
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
  exit(L2,kill).

