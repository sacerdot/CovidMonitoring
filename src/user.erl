-module(user).
-export([test/0, sleep/1, main/0, list/1, check_list/1, take_random/2]).
-import(luogo, [init_luogo/0]).
-import(server, [init_server/1]).

sleep(T) ->
  receive after T -> ok end.

%protocollo mantenimento topologia
main() ->
  PID = global:whereis_name(server),
  case PID of
    undefined -> exit(server_not_registered);
    P -> link(P),
      PidList = spawn_link(?MODULE, list, [[]]),
      check_list(PidList)
  end.

%attore che gestisce la lista
list(L) ->
  io:format("[ActorList] active places: ~p~n", [L]),
  receive
    {get_list, Pid} ->
      Pid ! L,
      list(L);
    {update_list, L1} ->
      [monitor(process, X) || X <- L1],
      list(L1 ++ L);
  %monitor del luogo morto
    _ -> get_places_updates(self(), L)
  end.

%% TODO add to utils
%% L1 -- L2
set_subtract(L1, L2) ->
  lists:filter(fun(X) -> not lists:member(X, L2) end, L1).

take_random([], _) -> [];
take_random(_, 0) -> [];
take_random(L, N) ->
  E = lists:nth(rand:uniform(length(L)), L),
  R = take_random(set_subtract(L, [E]), N - 1),
  [E | R].


get_places_updates(ActorList, L) ->
  global:send(server, {get_places, self()}),
  receive
    {places, PIDLIST} ->
      R = set_subtract(PIDLIST, L),
      ListLength = length(L),
      case ListLength of
        0 -> ActorList ! {update_list, take_random(R, 3)};
        1 -> ActorList ! {update_list, take_random(R, 2)};
        2 -> ActorList ! {update_list, take_random(R, 1)}
      end
  end.

check_list(ActorList) ->
  ActorList ! {get_list, self()},
  receive
    L ->
      case length(L) >= 3 of
        true -> ok;
        false -> get_places_updates(ActorList, L)
      end
  end,
  sleep(10000),
  check_list(ActorList).

%funziona lanciando il server prima di questo
test() ->
  L = [],
  S = spawn(server, init_server, [L]),
  global:register_name(server, S),
%%  Parco = spawn(luogo, init_luogo, []),
%%  Universita = spawn(luogo, init_luogo, []),
  Manfredonia = spawn(luogo, init_luogo, []),
  Foggia = spawn(luogo, init_luogo, []),
  spawn(?MODULE, main, []),
  spawn(?MODULE, main, []),
  spawn(?MODULE, main, []),
  spawn(?MODULE, main, []),
  spawn(?MODULE, main, []).

