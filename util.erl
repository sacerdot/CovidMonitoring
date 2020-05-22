-module(util).
-export([probability/1, probability1/1, test_probability/2, rand_in_range/2, sleep/1, rand_in_list/1]).

probability(N) ->
    P = rand:uniform(N),
    case P of
       1 -> true;
       _ -> false
    end.

%%%%%%%%%%Nuova funzione di probabilità per utilizzare le percentuali%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
probability1(N) ->
   rand:uniform(100) < N. 

%%%%%%%%%%% Test per vedere se probability1 funziona %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
test_probability(Prob, TestNum) -> test_probability(Prob, TestNum, TestNum, 0).
test_probability(_, 0, TestNum, Res) -> io:format("Res ~p TestNum ~p~n", [Res, TestNum]), Res/TestNum;
test_probability(Prob, N, TestNum, Res) ->
   case probability1(Prob) of
      true -> test_probability(Prob, N-1, TestNum, Res+1);
      false -> test_probability(Prob, N-1, TestNum, Res)
   end.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
   
rand_in_range(Min, Max) ->
	rand:uniform(Max-Min)+Min.

rand_in_list(List) ->
   lists:nth(rand:uniform(length(List)), List).

sleep(M) ->
   receive after M -> ok end.
