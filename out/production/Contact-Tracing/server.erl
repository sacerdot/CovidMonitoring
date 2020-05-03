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
  sleep(rand:uniform(5000)),
  exit (ciccio).

luogo2() ->
  global:send(server, {new_place, self()}) ,
  global:send(server, {new_place, self()}) ,
  sleep(rand:uniform(5000)),
  exit (ciccio).

main() ->
  Init = spawn(?MODULE, init, [[]]),
  global:register_name(server, Init),
  sleep(2000),
  spawn(?MODULE, luogo, []),
  L2 = spawn(?MODULE, luogo2, []),
  L3 = spawn(?MODULE, luogo, []),
  spawn(?MODULE, luogo2, []),
  spawn(?MODULE, luogo, []),
  exit(L2,kill),
  exit(L3, kill).

