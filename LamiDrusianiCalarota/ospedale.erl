-module(ospedale).
-export([start/0]).

test() -> 
	receive
		{test_me,Pid} -> 
			case rand:uniform(4) of
				1 -> Pid ! positive;
				_ -> Pid ! negative
			end
	end,
	test().
	
ospedale() ->
      	global:register_name(hospital,self()),
        Server = global:whereis_name(server),
	%link al server
	test().

start() -> vedereComeFare.
