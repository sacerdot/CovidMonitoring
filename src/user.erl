-module(user).
-export([test/0, sleep/1, main/0, list/1, check_list/1]).
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

get_places_updates(ActorList, L) ->
  global:send(server, {get_places, self()}),
  receive
    {places, PIDLIST} ->
      R = PIDLIST -- L,
      E1 = lists:nth(rand:uniform(length(R)), R),
      ListLength = length(L),
      io:format("listLength ~p~n", [ListLength]),
      case ListLength of %% aggiungere case 0 e _ 
        1 -> E2 = lists:nth(rand:uniform(length(R - E1)), R),
          ActorList ! {update_list, [E1, E2]};
        2 -> ActorList ! {update_list, [E1]}
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
  Parco = spawn(luogo, init_luogo, []),
  Universita = spawn(luogo, init_luogo, []),
  Manfredonia = spawn(luogo, init_luogo, []),
  Foggia = spawn(luogo, init_luogo, []),
  User1 = spawn(?MODULE, main, []),
  User2 = spawn(?MODULE, main, []).

