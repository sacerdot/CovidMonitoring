%%%-------------------------------------------------------------------
%%% @author Lorenzo_Stacchio
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 01. mag 2020 11:44
%%%-------------------------------------------------------------------
-module(user).
-author("Lorenzo_Stacchio").
%% API
-export([user/0, places_manager/1, get_places/3, test_manager/0, server/1, simple_location/1, simple_hospital/0, visit_manager/1]).
-define(TIMEOUT_LOCATION_MANAGER, 10000).
-define(TIMEOUT_TEST_MANAGER, 30000).

% number of places a user keep track
-define(USER_PLACES_NUMBER, 3).



sleep(N) -> receive after N -> ok end.


%-----------SERVER, LOCATION,HOSPITAL SIMULATED-----------
server(L) ->
  io:format("Lista totale server ~p~pPID,~p~n", [L, length(L), self()]),
  receive
    {remove_place, PL} ->
      if length(L) > 1 -> io:format("Rimosso in server ~p~n", [PL]), server(L--[PL]);
        true -> exit(normal)
      end;
    {get_places, P} -> %io:format("Messaggio ricevuto in server ~n", []),
      P ! {places, L}
      , server(L);
    {add_place, PL} -> server(L ++ [PL])
  end.

% the parameter N is for distinguish between first and successive recursion
simple_location(N) ->
  if %successive recursion case
    N == 1 ->
      % send a message to the server adding a new location
      server ! {add_place, self()}, simple_location(0);
    true ->
      sleep(200),
      % probability of 0,1 % to die for location
      C = rand:uniform(10000),
      case (C < 10) of
        true -> %io:format("C in random dead~p~n", [C]),
          io:format("Death of ~p~n", [self()]),
          % update server and location manager
          server ! {remove_place, self()},
          places_manager ! {luogo_morto, self()},
          exit(luogo_morto2);
        false -> simple_location(0)
      end
  end.

simple_hospital() ->
  io:format("Hospital PID~p~n", [self()]),
  receive
    {test_me, PID} ->
      P = rand:uniform(4),
      case (P == 1) of
        true -> PID ! {positive};
        false -> PID ! {negative}
      end,
      simple_hospital()
  end.

%----------------------USER----------------------
%-----------Topology maintenance protocol-----------

get_random_elements_from_list(ACTIVE_PLACES,N, LIST_USER) ->
  if length(LIST_USER)<N ->
    X = rand:uniform(length(ACTIVE_PLACES)),
    get_random_elements_from_list(lists:delete(lists:nth(X,ACTIVE_PLACES),ACTIVE_PLACES),
      N, lists:append(LIST_USER, [lists:nth(X, ACTIVE_PLACES)]));
  true ->
    LIST_USER
  end.

% retrieves N places and add their PID to LIST_TO_RETURN, answer to PID when completed
get_places(N, LIST_TO_RETURN, PID) ->
  if
    length(LIST_TO_RETURN) < N ->
      server ! {get_places, self()},
      receive
        {places, ACTIVE_PLACES} ->
          case length(ACTIVE_PLACES) > N of
            true -> get_random_elements_from_list(ACTIVE_PLACES,N,LIST_TO_RETURN);
            % not enough active places, die
            false -> exit(self(), kill)
          end
      end;
    true -> PID ! {new_places, LIST_TO_RETURN}, visit_manager ! {new_places, LIST_TO_RETURN}
  %TODO: inserire messaggio a visits
  end.


places_manager(L) ->
  io:format("LOCATION MANTAINER~p,~p,~n", [L, length(L)]),
  process_flag(trap_exit, true),
  %link(server),
  sleep(?TIMEOUT_LOCATION_MANAGER),
  % spawn a process to asynchronously retrieve {USER_PLACES_NUMBER} active places
  PID_GETTER = spawn(?MODULE, get_places, [?USER_PLACES_NUMBER, L, self()]),
  receive
    {'EXIT', PLACE_PID, Reason} ->
      io:format("Post mortem EXIT1 ~p, ~n",[Reason]),

        case  length(L) > 0 of
          true -> exit(PID_GETTER, kill),
            io:format("Post mortem EXIT2 ~p,~p,~p,~n", [PLACE_PID, L--[PLACE_PID], length(L--[PLACE_PID])]),
            places_manager(L--[PLACE_PID]);
          false -> exit(PID_GETTER, kill), places_manager(L)
        end;
    {new_places, LR} ->
      [link(PID) || PID <- LR],
      io:format("Link fatto EXIT~n",[]),
      places_manager(LR)
  end.

%-----------Visit protocol-----------
visit_manager(L) ->
  io:format("VISIT MANAGER init ~p~p~n", [L,self()]),
  % Not blocking receive to get places updates (if any)
  receive
    {new_places, UL} ->
      io:format("VISIT MANAGER Update~p ~n", [UL]),
      visit_manager(UL)
  after 0 ->
    ok
  end,
  case length(L) == 0 of
    true ->
      io:format("VISIT MANAGER TRUE before ~p ~n", [L]),
      receive
      {new_places, UL2} ->
        io:format("VISIT MANAGER TRUE after ~p ~n", [UL2]),
        visit_manager(UL2)
      end;
    false ->
      io:format("VISIT MANAGER FALSE ~p ~n", [L]),
      sleep(2 + rand:uniform(3)),
      % Ref unused actually
      Ref = make_ref(),
      P = lists:nth(rand:uniform(length(L)),L),
      P ! {begin_visit, self(), Ref},
      sleep(4 + rand:uniform(6)),
      P ! {end_visit, self(), Ref},
      visit_manager(L)
  end.

%-----------Test protocol-----------

% user ask hospital to make illness tests
test_manager() ->
  sleep(?TIMEOUT_TEST_MANAGER),
  case (rand:uniform(4) == 1) of
    true ->
      io:format("TEST covid ~p~n", [hospital ! {test_me, self()}]), hospital ! {test_me, self()};
    false ->
      test_manager()
  end,
  receive
    {positive} -> io:format("~p: Entro in quarantena~n", [self()]), exit(quarantena);
    {negative} -> io:format("~p NEGATIVO~n", [self()]), test_manager()
  end.

%-----------Main-----------
%TODO: Manage the death of user() when one from M,T dies with a MONITOR.
user() ->
  %mettere link al server
  N = lists:seq(0, 10),
  SERVER = spawn_link(?MODULE, server, [[]]),
  register(server, SERVER), %rendo pubblico associazione nome PID
  % spawn N locations
  [spawn(?MODULE, simple_location, [1]) || X <- N],
  io:format("SERVER SPAWNED~p~n", [SERVER]),
  PLACES_MANAGER = spawn_link(?MODULE, places_manager, [[]]),
  register(places_manager, PLACES_MANAGER),
  io:format("LOCATION MANAGER SPAWNED~p~n", [PLACES_MANAGER]),
  HOSPITAL = spawn_link(?MODULE, simple_hospital, []),
  register(hospital, HOSPITAL),
  io:format("HOSPITAL SPAWNED~p~n", [HOSPITAL]),
  VISIT_MANAGER = spawn_link(?MODULE, visit_manager, [[]]),
  register(visit_manager, VISIT_MANAGER),
  io:format("VISITOR MANAGER SPAWNED~p~n", [VISIT_MANAGER]),
  TEST_MANAGER = spawn_link(?MODULE, test_manager, []),
  register(test_manager, TEST_MANAGER),
  io:format("TEST MANAGER SPAWNED~p~n", [TEST_MANAGER]).


