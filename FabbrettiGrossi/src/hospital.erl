-module(hospital).
-export([init/0, loop/0]).


init() ->
    Result = global:register_name(hospital, self()),
    case Result of
	yes -> loop();
	no -> io:format("Something went wrong during hospital init.~n")
    end.

loop() ->
    receive
	{test_me, Pid} ->
	    Result = rand:uniform(4),
	    case Result of
		4 -> Pid ! positive;
		_ -> Pid ! negative
	    end,
	    loop();
	Other -> io:format("Unexpected message: ~p~n", [Other]),
		 loop()
    end.
