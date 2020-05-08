-module(user).
-export([test/0, sleep/1, mainU/0, list/1, check_list/1, visit_places/1, contact_tracing/0, compile/0]).
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
    P -> link(P),
      ActorDisaptcher() 
  end.

ActorDisaptcher() -> 
  ActorList = spawn_link(?MODULE, list, [self(), []]),
  ActorCheckList = spawn_link(?MODULE, check_list, [ActorList, self()]),
  ActorVisitPlace = spawn_link(?MODULE, visit_places, [self()]),
  ActorContactTrace = spawn_link(?MODULE, contact_tracing, []),
  ActorRequiredTest = spawn_link(?MODULE, require_test, [self()]),
  ActorMergeList = spawn_link(?MODULE, get_places_updates, [ActorList, []]),
  loop(ActorList, ActorCheckList, ActorVisitPlace, ActorContactTrace, ActorRequiredTest, ActorMergeList).

loop(List, CheckList, VisitPlace, ContactTrace, RequiredTest, MergList) ->
  receive 
    {places, PIDLIST} -> MergList ! {places, PIDLIST}
    {} -> 
  end

% attore che gestisce la lista
list(PidDispatcher, L) ->
  %io:format("[ActorList] active places: ~p~n", [L]),
  receive
    {get_list, Pid} ->
      Pid ! L,
      list(L);
    {update_list, L1} ->
      % monitoro tutti i luoghi nella lista L1
      [monitor(process, X) || X <- L1],
      list(L1 ++ L);
      % messages from a dead place (DOWN)
    _ -> global:send(server, {get_places, PidDispatcher}),
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

get_places_updates(ActorList) ->
  receive
    % aspetto il messaggio dal server con i luoghi attivi
    {places, PIDLIST} ->
      % chiedo all'attore List la mia lista ttuale dei luoghi
      ActorList ! {get_list, self()}
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
  end.

check_list(ActorList) ->
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
  check_list(ActorList).

visit_places(ActorList) ->
  ActorList ! {get_list, self()},
  receive
    L ->
      io:format("[Visit place] Lista dei places:~p ~n", [L]),
      case length(L) >= 1 of
        true ->
          REF = make_ref(),
          [LUOGO|_] = take_random(L, 1),
          LUOGO ! {begin_visit, self(), REF},
          sleep(5000 + rand:uniform(5000)),
          LUOGO ! {end_visit, self(), REF};
        false -> ok
      end,
      sleep(3000 + rand:uniform(2000)),
      visit_places(ActorList)
  end.

contact_tracing() ->
  receive
    {contact, PID} ->
      link(PID),
      io:format("[User] ~p si è linkato a ~p~n", [self(), PID]),
      process_flag(trap_exit, true),
      contact_tracing();
    {'EXIT', _, R} -> % TODO rewrite
      case R of
        quarantine ->
          io:format("[User] ~p entro in quaratena ~n", [self()]),
          exit(quarantine);
        positive ->
          io:format("[User] ~p entro in quaratena ~n", [self()]),
          exit(quarantine);
        _ ->
          io:format("[User] ~p get an exit msg with reason ~n", [R]),
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
        negative -> io:format("[User] Sono negativo ~n");
        Msg -> io:format("Arrivato un messaggio ~p ~n", [Msg])
      end;
    _ -> ok
  end,
  require_test().


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

  io:format("[User] ~p~n", [ spawn(?MODULE, mainU, [])]),
  io:format("[User] ~p~n", [ spawn(?MODULE, mainU, [])]),
  io:format("[User] ~p~n", [ spawn(?MODULE, mainU, [])]),
  io:format("[User] ~p~n", [ spawn(?MODULE, mainU, [])]),
  io:format("[User] ~p~n", [ spawn(?MODULE, mainU, [])]),
  io:format("[User] ~p~n", [ spawn(?MODULE, mainU, [])]),
  io:format("[User] ~p~n", [ spawn(?MODULE, mainU, [])]),
  io:format("[User] ~p~n", [ spawn(?MODULE, mainU, [])]).





