-module(utenti).
-export([main/0, list/2, check_list/2, visit_places/2, contact_tracing/1, actorDispatcher/0, get_places_updates/2, require_test/2, utente/0, start/0]).
-import(utils, [sleep/1, set_subtract/2, take_random/2, check_service/1, make_probability/1]).

main() ->
  PidServer = check_service(server),
  PidServer ! {ciao,da,utente,self()},
  link(PidServer),
  actorDispatcher().

actorDispatcher() ->
  process_flag(trap_exit, true),
  ActorList = spawn_link(?MODULE, list, [self(), []]),
  io:format("[ActorDispatcher] User ~p actorList ~p ~n", [self(), ActorList]),
  CheckList = spawn_link(?MODULE, check_list, [ActorList, self()]),
  io:format("[ActorDispatcher] User ~p checklist ~p ~n", [self(), CheckList]),
  VisitPlace = spawn_link(?MODULE, visit_places, [ActorList, self()]),
  io:format("[ActorDispatcher] User ~p visitplace ~p ~n", [self(), VisitPlace]),
  ActorContactTrace = spawn_link(?MODULE, contact_tracing, [self()]),
  io:format("[ActorDispatcher] User ~p actorContactTrace ~p ~n", [self(), ActorContactTrace]),
  ActorRequiredTest = spawn_link(?MODULE, require_test, [self(), make_probability(25)]),
  io:format("[ActorDispatcher] User ~p ActorRequiredTest ~p ~n", [self(), ActorRequiredTest]),
  ActorMergeList = spawn_link(?MODULE, get_places_updates, [self(), ActorList]),
  io:format("[ActorDispatcher] User ~p ActorMergeList ~p ~n", [self(), ActorMergeList]),
  loop(ActorContactTrace, ActorRequiredTest, ActorMergeList).

loop(ContactTrace, RequiredTest, MergList) ->
  receive
    {places, PIDLIST} ->
      MergList ! {places, PIDLIST};
    {contact, PID} -> ContactTrace ! {contact, PID};
    positive -> RequiredTest ! positive;
    negative -> RequiredTest ! negative;
    {'EXIT', Sender, R} -> 
    io:format("[Dispatcher] ~p received exit from ~p with: ~p~n", [self(), Sender, R]), 
    exit(R);
    Msg ->
      % Check unexpected message from other actors
      io:format("[Dispatcher] ~p  ~p~n", [self(), Msg])
  end,
  loop(ContactTrace, RequiredTest, MergList).

% actor handling list
list(PidDispatcher, L) ->
  receive
    {get_list, Pid} ->
      Pid ! L,
      list(PidDispatcher, L);
    {update_list, L1} ->
      % monitor all places in L1
      [monitor(process, X) || X <- L1],
      list(PidDispatcher, L1 ++ L);
      % messages from a dead place (DOWN)
    {_, _, process, _, _} ->
      global:send(server, {get_places, PidDispatcher}),
      list(PidDispatcher, L);
    Msg ->
      % Check unexpected message from other actors
      io:format("[User] ~p Messaggio non gestito ~p~n", [self(), Msg]),
      list(PidDispatcher, L)
  end.

get_places_updates(PidDispatcher, ActorList) ->
  receive
    {places, PIDLIST} ->
      ActorList ! {get_list, self()},
      receive
        L ->
          R = set_subtract(PIDLIST, L),
          case length(L) of
            0 -> ActorList ! {update_list, take_random(R, 3)};
            1 -> ActorList ! {update_list, take_random(R, 2)};
            2 -> ActorList ! {update_list, take_random(R, 1)};
            _ -> ok
          end
      end
  end,
  get_places_updates(PidDispatcher, ActorList).

check_list(ActorList, PidDispatcher) ->
  ActorList ! {get_list, self()},
  receive
    L ->
      case length(L) >= 3 of
        true -> ok;
        false ->
          global:send(server, {get_places, PidDispatcher})
      end
  end,
  sleep(10000),
  check_list(ActorList, PidDispatcher).

visit_places(ActorList, PidDispatcher) ->
  ActorList ! {get_list, self()},
  receive
    L ->
      case length(L) >= 1 of
        true ->
          REF = make_ref(),
          [LUOGO|_] = take_random(L, 1),
          LUOGO ! {begin_visit, PidDispatcher, REF},
          sleep(5000 + rand:uniform(5000)),
          LUOGO ! {end_visit, PidDispatcher, REF};
        false -> ok
      end,
      sleep(3000 + rand:uniform(2000)),
      visit_places(ActorList, PidDispatcher)
  end.

contact_tracing(PidDispatcher) ->
  process_flag(trap_exit, true),
  contact_tracing_loop(PidDispatcher).
contact_tracing_loop(PidDispatcher) ->
  receive
    {contact, PID} ->
      %let it fail
      %try
      link(PID),
      io:format("[User] ~p linked to ~p~n", [PidDispatcher, PID]),
      %catch X ->
      %  io:format("[User] ~p unable to link to ~p error ~p~n", [PidDispatcher, PID, X])
      %end,
      contact_tracing_loop(PidDispatcher);
    {'EXIT', _, R} ->
      case R of
        quarantine ->
          io:format("[User] ~p entro in quaratena ~n", [PidDispatcher]),
          exit(quarantine);
        positive ->
          io:format("[User] ~p entro in quaratena ~n", [PidDispatcher]),
          exit(quarantine)
      end ;
    Msg ->
      % Check unexpected message from other actors
      io:format("[User] ~p Messaggio non gestito ~p~n", [self(), Msg])
  end.

require_test(PidDispatcher, Probability) ->
  sleep(30000),
  case Probability() of
    1 ->
      PidOspedale = check_service(ospedale),
      PidOspedale ! {test_me, PidDispatcher},
      receive
        positive ->
          io:format("[User] ~p sono positivo ~n", [PidDispatcher]),
          exit(positive);
        negative -> io:format("[User] ~p Sono negativo ~n", [PidDispatcher])
      end;
    _ -> ok
  end,
  require_test(PidDispatcher, Probability).

utente() ->
  io:format("Io sono l'utente ~p~n",[self()]),
  main().

start() ->
  [ spawn(fun utente/0) || _ <- lists:seq(1,10) ].