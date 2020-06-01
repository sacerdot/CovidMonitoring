-module(utils).
-export([sleep/1, set_subtract/2, get_random/2, make_probability/1, check_service/1]).

sleep(T) ->
  receive after T -> ok end.

%% L1 -- L2
set_subtract(L1, L2) ->
  lists:filter(fun(X) -> not lists:member(X, L2) end, L1).

get_random(L, N) ->
  F = fun(_, _, 0, Result) -> Result;
    (_, [], _, Result) -> Result;
    (_, _, Number, _) when Number < 0 -> [];
    (Fun, List, Number, []) ->
      E = lists:nth(rand:uniform(length(List)), List),
      Fun(Fun, set_subtract(List, [E]), Number - 1, [E]);
    (Fun, List, Number, Result) ->
      E = lists:nth(rand:uniform(length(List)), List),
      Fun(Fun, set_subtract(List, [E]), Number - 1, [E | Result])
      end,
  F(F, L, N, []).

make_probability(X) ->
  fun() ->
    rand:uniform(100) =< X
  end.

% Check server and ospedale
check_service(X) ->
  PidService = global:whereis_name(X),
  case PidService of
    undefined ->
      io:format("~p non trovato ~n", [X]),
      case X of
        ospedale -> exit(ospedale_not_registered);
        server -> exit(server_not_registered)
      end;
    P -> P
  end.