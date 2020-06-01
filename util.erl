-module(util).
-export([probability/1, rand_in_range/2, sleep/1, rand_in_list/1]).

%probability(N) ->
%    P = rand:uniform(N),
%    case P of
%       1 -> true;
%       _ -> false
%    end.

probability(N) ->
   rand:uniform(100) < N. 

   
rand_in_range(Min, Max) ->
	rand:uniform(Max-Min)+Min.

rand_in_list(List) ->
   lists:nth(rand:uniform(length(List)), List).

sleep(M) ->
   receive after M -> ok end.
