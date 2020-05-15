-module(ospedale).
-export([start/0, test/1]).
-import(utils, [make_probability/1]).

test(Probability) ->
  receive
    {test_me, PID} ->
      io:format("~p require a test~n", [PID]),
      case Probability() of
        1 -> PID ! positive;
        _ -> PID ! negative
      end,
      test(Probability)
  end.

start() ->
  io:format("Io sono l'ospedale~n", []),
  global:register_name(ospedale, self()),
  Server = global:whereis_name(server),
  Server ! {ciao, da, ospedale},
  Prob25 = make_probability(25),
  test(Prob25).