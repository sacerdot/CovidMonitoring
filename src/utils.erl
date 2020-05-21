-module(utils).
-export([sleep/1, set_subtract/2, take_random/2, make_probability/1, check_service/1, flush/1]).

sleep(T) ->
  receive after T -> ok end.

%% L1 -- L2
set_subtract(L1, L2) ->
  lists:filter(fun(X) -> not lists:member(X, L2) end, L1).

take_random([], _) -> [];
take_random(_, 0) -> [];
take_random(L, N) ->
  E = lists:nth(rand:uniform(length(L)), L),
  R = take_random(set_subtract(L, [E]), N - 1),
  [E | R].

flush(X) ->
  receive
    X -> flush(X)
  after
    0 -> ok
  end.


make_probability(X) ->
  fun () ->
    case (rand:uniform(100) =< X) of
      true -> 1;
      false -> 0
    end
  end.

%check server and ospedale
check_service(X) ->
  PidService = global:whereis_name(X),
  case PidService of
    undefined ->
      io:format("~p non trovato ~n", [X]),
      exit(server_not_registered);
    P -> P
  end.