-module(hospital).
-export([main/0, test/0]).

test() ->
  receive
    {test_me, PID} ->
      io:format("~p require a test~n", [PID]),
      case rand:uniform(4) of
        1 -> PID ! positive;
        _ -> PID ! negative
      end, test()
  end.

 
main() ->
  global:register_name(hospital, self()),
  spawn(?MODULE, test, []).