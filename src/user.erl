-module(user).
-export([test/0, sleep/1, mainU/0, list/2, check_list/2, visit_places/2, contact_tracing/1, compile/0, actorDispatcher/0, get_places_updates/2, require_test/1]).
-import(luogo, [init_luogo/0]).
-import(server, [init_server/1]).
-import(hospital, [main/0]).

compile() ->
  compile:file('hospital.erl'),
  compile:file('luogo.erl'),
  compile:file('server.erl').

sleep(T) ->
  receive after T -> ok end.

% protocollo mantenimento topologia
mainU() ->
  PID = global:whereis_name(server),
  case PID of
    undefined -> exit(server_not_registered);
    P ->
      link(P),
      actorDispatcher()
  end.

actorDispatcher() ->
  ActorList = spawn_link(?MODULE, list, [self(), []]),
  spawn_link(?MODULE, check_list, [ActorList, self()]),
  spawn_link(?MODULE, visit_places, [ActorList, self()]),
  ActorContactTrace = spawn_link(?MODULE, contact_tracing, [self()]),
  ActorRequiredTest = spawn_link(?MODULE, require_test, [self()]),
  ActorMergeList = spawn_link(?MODULE, get_places_updates, [self(), ActorList]),
  loop(ActorContactTrace, ActorRequiredTest, ActorMergeList).

loop(ContactTrace, RequiredTest, MergList) ->
  receive
    {places, PIDLIST} ->
      %io:format("[Dispatcher] Received places from server with PIDLIST: ~p~n", [PIDLIST]),
      MergList ! {places, PIDLIST};
    {contact, PID} -> ContactTrace ! {contact, PID};
    positive -> RequiredTest ! positive;
    negative -> RequiredTest ! negative;
    Msg -> io:format("[Dispatcher] Messaggio non gestito: ~p~n", [Msg])
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
    _ -> global:send(server, {get_places, PidDispatcher})
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
  receive
    {contact, PID} ->
      link(PID),
      io:format("[User] ~p linked to ~p~n", [PidDispatcher, PID]),
      process_flag(trap_exit, true),
      contact_tracing(PidDispatcher);
    {'EXIT', _, R} -> % TODO rewrite
      case R of
        quarantine ->
          io:format("[User] ~p enter quarantine ~n", [PidDispatcher]),
          exit(quarantine);
        positive ->
          io:format("[User] ~p enter quarantine ~n", [PidDispatcher]),
          exit(quarantine);
        _ ->
          io:format("[User] ~p get an exit msg with reason ~p ~n", [PidDispatcher, R]),
          % TODO check logic
          exit(R)
      end;
    Msg -> io:format("[Contact Tracing] Catturata exit ~p~n", [Msg])
  end.

require_test(PidDispatcher) ->
  sleep(30000),
  case rand:uniform(4) of
    1 ->
      global:send(hospital, {test_me, PidDispatcher}),
      receive
        positive ->
          io:format("[User] ~p sono positivo ~n", [PidDispatcher]),
          exit(positive);
        negative -> io:format("[User] ~p Sono negativo ~n", [PidDispatcher]);
        % Tmp Msg
        Msg -> io:format("Arrivato un messaggio ~p ~n", [Msg])
      end;
    _ -> ok
  end,
  require_test(PidDispatcher).


% funziona lanciando il server prima di questo
test() ->
  S = spawn(server, init_server, [[]]),
  global:register_name(server, S),
  spawn(hospital, main, []),

  spawn(luogo, init_luogo, []),
  spawn(luogo, init_luogo, []),
  spawn(luogo, init_luogo, []),
  spawn(luogo, init_luogo, []),
  spawn(luogo, init_luogo, []),
  spawn(luogo, init_luogo, []),
  spawn(luogo, init_luogo, []),
  spawn(luogo, init_luogo, []),
  spawn(luogo, init_luogo, []),

  io:format("[User] ~p~n", [ spawn(?MODULE, mainU, [])]),
  io:format("[User] ~p~n", [ spawn(?MODULE, mainU, [])]),
  io:format("[User] ~p~n", [ spawn(?MODULE, mainU, [])]),
  io:format("[User] ~p~n", [ spawn(?MODULE, mainU, [])]),
  io:format("[User] ~p~n", [ spawn(?MODULE, mainU, [])]),
  io:format("[User] ~p~n", [ spawn(?MODULE, mainU, [])]).





