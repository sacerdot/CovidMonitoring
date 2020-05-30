-module(utenti).
-export([main/0, list_handler/2, check_list/2, visit_place/2, actorDispatcher/0, require_test/2, utente/0, start/0]).
-import(utils, [sleep/1, set_subtract/2, get_random/2, check_service/1, make_probability/1]).

%%%%%%%%%%%%%%%%%%%%%%%%%%% PROTOCOLLO DI MANTENIMENTO DELLA TOPOLOGIA (a) %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
main() ->
  PidServer = check_service(server),
  PidServer ! {ciao, da, utente, self()},
  link(PidServer),
  actorDispatcher().

actorDispatcher() ->
  process_flag(trap_exit, true),
  ActorListHandler = spawn_link(?MODULE, list_handler, [self(), []]),
  %io:format("[ActorDispatcher] User ~p ActorListHandler ~p ~n", [self(), ActorListHandler]),
  ActorCheckList = spawn_link(?MODULE, check_list, [ActorListHandler, self()]),
  %io:format("[ActorDispatcher] User ~p CheckList ~p ~n", [self(), CheckList]),
  ActorVisitPlace = spawn_link(?MODULE, visit_place, [ActorListHandler, self()]),
  %io:format("[ActorDispatcher] User ~p ActorVisitPlace ~p ~n", [self(), ActorVisitPlace]),
  ActorRequireTest = spawn_link(?MODULE, require_test, [self(), make_probability(25)]),
  %io:format("[ActorDispatcher] User ~p ActorRequireTest ~p ~n", [self(), ActorRequireTest]),
  %sleep(1000),
  dispatcher_loop(ActorListHandler, ActorRequireTest, ActorVisitPlace, ActorCheckList).

dispatcher_loop(ListHandler, RequireTest, VisitPlace, CheckList) ->
  receive
    {places, PIDLIST} ->
      update_list(ListHandler, PIDLIST),
      dispatcher_loop(ListHandler, RequireTest, VisitPlace, CheckList);
    {contact, PID} ->
      link_user(PID),
      dispatcher_loop(ListHandler, RequireTest, VisitPlace, CheckList);
    positive ->
      io:format("[Dispatcher] ~p sono positivo ~n", [self()]),
      exit(positive);
    negative ->
      io:format("[Dispatcher] ~p Sono negativo ~n", [self()]),
      dispatcher_loop(ListHandler, RequireTest, VisitPlace, CheckList);
    {'EXIT', _, X} when X =:= quarantine; X =:= positive ->
      io:format("[Dispatcher] ~p entro in quarantena ~n", [self()]),
      exit(quarantine);
    {'EXIT', RequireTest, R} ->
      io:format("[Dispatcher] ~p RequireTest morto: ~p da ~p ~n", [self(), R, RequireTest]),
      dispatcher_loop(ListHandler, spawn_link(?MODULE, require_test, [self(), make_probability(25)]), VisitPlace, CheckList);
    {'EXIT', VisitPlace, R} ->
      io:format("[Dispatcher] ~p VisitPlace morto: ~p da ~p ~n", [self(), R, VisitPlace]),
      dispatcher_loop(ListHandler, RequireTest, spawn_link(?MODULE, visit_place, [ListHandler, self()]), CheckList);
    {'EXIT', CheckList, R} ->
      io:format("[Dispatcher] ~p CheckList morto: ~p da ~p ~n", [self(), R, CheckList]),
      dispatcher_loop(ListHandler, RequireTest, VisitPlace, spawn_link(?MODULE, check_list, [ListHandler, self()]));
    {'EXIT', ListHandler, R} ->
      io:format("[Dispatcher] ~p ListHandler morto: ~p da ~p ~n", [self(), R, ListHandler]),
      dispatcher_loop(spawn_link(?MODULE, list_handler, [self(), []]), RequireTest, VisitPlace, CheckList);
    {'EXIT', Sender, R} ->
      io:format("[Dispatcher] ~p catturato evento: ~p da ~p ~n", [self(), R, Sender]),
      exit(R)
  end.

link_user(PID) ->
  % check if PID is alive before linking
  case erlang:process_info(PID) == undefined of
    true -> io:format("[Dispatcher] ~p impossibile linkarsi a ~p~n", [self(), PID]);
    false ->
      link(PID),
      io:format("[Dispatcher] ~p linkato a ~p~n", [self(), PID])
  end.

%%%%%%%%%%%%%%%%%%%%%%%%%%% PROTOCOLLO DI MANTENIMENTO DELLA TOPOLOGIA (b) %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
list_handler(PidDispatcher, L) ->
  receive
    {get_list, Pid} ->
      Pid ! {list, L},
      list_handler(PidDispatcher, L);
    {update_list, L1} ->
      % monitor all places in L1
      [monitor(process, X) || X <- L1],
      list_handler(PidDispatcher, L1 ++ L);
  % messages from a dead place (DOWN)
    {'DOWN', _, process, Pid, _} ->
      global:send(server, {get_places, PidDispatcher}),
      list_handler(PidDispatcher, set_subtract(L, [Pid]))
  end.

update_list(ListHandler, PIDLIST) ->
  L = get_list(ListHandler),
  R = set_subtract(PIDLIST, L),
  ListHandler ! {update_list, get_random(R, 3 - length(L))}.

get_list(ListHandler) ->
  ListHandler ! {get_list, self()},
  receive
    {list, L} -> L
  end.

%%%%%%%%%%%%%%%%%%%%%%%%%%% PROTOCOLLO DI MANTENIMENTO DELLA TOPOLOGIA (c, d) %%%%%%%%%%%%%%%%%%%%%%%%%%
check_list(ListHandler, PidDispatcher) ->
  L = get_list(ListHandler),
  case length(L) < 3 of
    true -> global:send(server, {get_places, PidDispatcher});
    false -> ok
  end,
  sleep(10000),
  check_list(ListHandler, PidDispatcher).

%%%%%%%%%%%%%%%%%%%%%%%%%%% PROTOCOLLO DI VISITA DEI LUOGHI %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
visit_place(ListHandler, PidDispatcher) ->
  L = get_list(ListHandler),
  case length(L) >= 1 of
    true ->
      REF = make_ref(),
      [LUOGO | _] = get_random(L, 1),
      LUOGO ! {begin_visit, PidDispatcher, REF},
      sleep(5000 + rand:uniform(5000)),
      LUOGO ! {end_visit, PidDispatcher, REF};
    false -> ok
  end,
  sleep(3000 + rand:uniform(2000)),
  visit_place(ListHandler, PidDispatcher).

%%%%%%%%%%%%%%%%%%%%%%%%%%% PROTOCOLLO DI TEST (a,b) %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
require_test(PidDispatcher, Probability) ->
  sleep(30000),
  case Probability() of
    true ->
      PidOspedale = check_service(ospedale),
      PidOspedale ! {test_me, PidDispatcher};
    false -> ok
  end,
  require_test(PidDispatcher, Probability).

utente() ->
  io:format("Io sono l'utente ~p~n", [self()]),
  main().

start() ->
  [spawn(fun utente/0) || _ <- lists:seq(1, 1000)].