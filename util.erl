-module(util).
-export([probability/1, rand_in_range/2, sleep/1]).

probability(N) ->
    P = rand:uniform(N),
    case P of
       1 -> true;
       _ -> false
    end.

rand_in_range(Min, Max) ->
	rand:uniform(Max-Min)+Min.

sleep(M) ->
   receive after M -> ok end.
