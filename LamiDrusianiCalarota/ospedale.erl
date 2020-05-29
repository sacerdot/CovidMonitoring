-module(ospedale).
-export([start/0]).

test() -> 
	receive
		{test_me,Pid} -> 
			case rand:uniform(4) of
				 1 -> Pid ! positive, test();
				 _ -> Pid ! negative, test()
			end
	end.

ospedale()->
    global:register_name(hospital,self()),
    test().

start() ->
	spawn(fun ospedale/0 ).

