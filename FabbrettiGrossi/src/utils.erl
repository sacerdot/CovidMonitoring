-module(utils).
-export([sample/2, sample/3]).


sample(N, L)->
    sample([], N, L).

sample(L,0,_) -> L;
sample(L1, N, L2) ->
    X = lists:nth(rand:uniform(length(L2)), L2),
    sample(L1 ++ X, N-1, [Y || Y <- L2, Y/= X]).

sleep(N) ->
    receive after N*1000 -> ok end.

sleep_random(I, S) ->
    X = rand:uniform(S-I),
    sleep(I+X).
