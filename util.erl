-module(util).
-export([probability/1]).

probability(N) ->
    P = rand:uniform(N),
    case P of
       1 -> true;
       _ -> false
    end.
