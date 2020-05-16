-module(ospedale).
-export([start/0, test/1]).
-import(utils, [make_probability/1, check_service/1]).

test(Probability) ->
  receive
    {test_me, PID} ->
      io:format("[Ospedale] User ~p require a test~n", [PID]),
      case Probability() of
        1 -> PID ! positive;
        _ -> PID ! negative
      end;
      Msg ->
        % Check unexpected message from other actors
        io:format("[Ospedale] Messaggio non gestito ~p~n", [Msg])
  end,
  test(Probability).

start() ->
  io:format("Io sono l'ospedale~n", []),
  global:register_name(ospedale, self()),
  PidServer = check_service(server),
  PidServer ! {ciao, da, ospedale},
  Prob25 = make_probability(25),
  test(Prob25).
