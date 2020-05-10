-module(hospital).
-export([main/0, test/0]).

test() ->
  receive
    {test_me, PID} ->
      %io:format("~p require a test~n", [PID]),
      case rand:uniform(4) of
        1 -> PID ! positive;
        %io:format("Messaggio inviato dall'ospedale ~n");
        _ -> PID ! negative
        %io:format("Messaggio inviato dall'ospedale ~n")
      end, 
    test()
  end.


main() ->
  H = spawn(?MODULE, test, []),
  global:register_name(hospital, H).
