-module(utenti).
-export([sleep/1, main/0, list/2, check_list/2, visit_places/2, contact_tracing/1, compile/0, actorDispatcher/0, get_places_updates/2, require_test/1, utente/0, start/0]).

compile() ->
  compile:file('ospedale.erl'),
  compile:file('luoghi.erl'),
  compile:file('server.erl').

sleep(T) ->
  receive after T -> ok end.

% protocollo mantenimento topologia
main() ->
  PID = global:whereis_name(server),
  case PID of
    undefined -> exit(server_not_registered);
    P ->
      P ! {ciao,da,utente,self()},
      link(P),
      actorDispatcher()
  end.

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
  ActorRequiredTest = spawn_link(?MODULE, require_test, [self()]),
  io:format("[ActorDispatcher] User ~p ActorRequiredTest ~p ~n", [self(), ActorRequiredTest]),
  ActorMergeList = spawn_link(?MODULE, get_places_updates, [self(), ActorList]),
  io:format("[ActorDispatcher] User ~p ActorMergeList ~p ~n", [self(), ActorMergeList]),
  loop(ActorContactTrace, ActorRequiredTest, ActorMergeList).

loop(ContactTrace, RequiredTest, MergList) ->
  receive
    {places, PIDLIST} ->
      %io:format("[Dispatcher] Received places from server with PIDLIST: ~p~n", [PIDLIST]),
      MergList ! {places, PIDLIST};
    {contact, PID} -> ContactTrace ! {contact, PID};
    positive -> RequiredTest ! positive;
    negative -> RequiredTest ! negative;
    {'EXIT', Sender, R} -> io:format("[Dispatcher] ~p received exit from ~p with: ~p~n", [self(), Sender, R]), exit(R)
    %Msg -> io:format("[Dispatcher] Messaggio non gestito: ~p~n", [Msg])
  end,
  loop(ContactTrace, RequiredTest, MergList).

% attore che gestisce la lista
list(PidDispatcher, L) ->
  %io:format("[ActorList] User ~p with active places: ~p~n", [PidDispatcher, L]),
  receive
    {get_list, Pid} ->
      %io:format("[ActorList] User ~p receveid get_list from pid: ~p~n", [PidDispatcher, Pid]),
      Pid ! L,
      list(PidDispatcher, L);
    {update_list, L1} ->
      %io:format("[ActorList] User ~p received update_list with places ~p ~n", [PidDispatcher, L1]),
      % monitoro tutti i luoghi nella lista L1
      [monitor(process, X) || X <- L1],
      list(PidDispatcher, L1 ++ L);
      % messages from a dead place (DOWN)
    _ ->
      global:send(server, {get_places, PidDispatcher}),
      list(PidDispatcher, L)
  end.

%% TODO add to utils
%% L1 -- L2
set_subtract(L1, L2) ->
  lists:filter(fun(X) -> not lists:member(X, L2) end, L1).

take_random([], _) -> [];
take_random(_, 0) -> [];
take_random(L, N) ->
  E = lists:nth(rand:uniform(length(L)), L),
  R = take_random(set_subtract(L, [E]), N - 1),
  [E | R].

get_places_updates(PidDispatcher, ActorList) ->
  receive
    % aspetto il messaggio dal server con i luoghi attivi
    {places, PIDLIST} ->
      % chiedo all'attore List la mia lista ttuale dei luoghi
      %io:format("[Get_Places_Updates] send get_list from pid: ~p~n", [self()]),
      ActorList ! {get_list, self()},
      receive
        L ->
          R = set_subtract(PIDLIST, L),
          %io:format("[get_places_updates] User ~p get_list ~p~n", [PidDispatcher, R]),
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
      %io:format("[Visit place] User ~p places: ~p ~n", [PidDispatcher, L]),
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
      try
        link(PID),
        io:format("[User] ~p linked to ~p~n", [PidDispatcher, PID])
      catch X ->
        io:format("[User] ~p unable to link to ~p error ~p~n", [PidDispatcher, PID, X])
      end,
      contact_tracing_loop(PidDispatcher);
    {'EXIT', PidExit, R} -> % TODO rewrite
      case R of
        quarantine ->
          io:format("[User] ~p enter quarantine from ~p ~n", [PidDispatcher, PidExit]),
          exit(quarantine);
        positive ->
          io:format("[User] ~p enter quarantine from ~p ~n", [PidDispatcher, PidExit]),
          exit(quarantine);
        _ ->
          io:format("[User] <D ~p, U ~p> get an exit msg from ~p with reason ~p ~n", [PidDispatcher,self(), PidExit, R]),
          % TODO check logic
          exit(R)
      end
    %Msg -> io:format("[Contact Tracing] Catturata exit ~p~n", [Msg])
  end.

require_test(PidDispatcher) ->
  sleep(30000),
  case rand:uniform(4) of
    1 ->
      global:send(ospedale, {test_me, PidDispatcher}),
      receive
        positive ->
          io:format("[User] ~p sono positivo ~n", [PidDispatcher]),
          exit(positive);
        negative -> io:format("[User] ~p Sono negativo ~n", [PidDispatcher])
        % Tmp Msg
        %Msg -> io:format("Arrivato un messaggio ~p ~n", [Msg])
      end;
    _ -> ok
  end,
  require_test(PidDispatcher).

utente() ->
  io:format("Io sono l'utente ~p~n",[self()]),
  main().

start() ->
  [ spawn(fun utente/0) || _ <- lists:seq(1,10) ].