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
-define(TIMEOUT_TEST_MANAGER, 500000).
% number of places a user keep track
-define(USER_PLACES_NUMBER, 3).


flush() ->
  receive
    _ -> flush()
  after
    0 -> ok
  end.

sleep(N) -> receive after N -> ok end.


%-----------SERVER, LOCATION,HOSPITAL SIMULATED-----------
server(L) ->
  process_flag(trap_exit, true),
  [link(PID) || PID <- L],
  io:format("Lista totale server ~p~pPID,~p~n", [L, length(L), self()]),
  receive
    {add_place, PL} -> server(L ++ [PL]);
    {'EXIT', PLACE_PID, Reason} ->
      io:format("Post mortem SERVER ~p, ~n", [Reason]),
      case length(L) > 0 of
        true -> io:format("Rimosso in server ~p~n", [PLACE_PID]), server(L--[PLACE_PID]);
        false -> exit(kill)
      end;
    {get_places, P} -> %io:format("Messaggio ricevuto in server ~n", []),
      P ! {places, L}
      , server(L)
  end.

% the parameter N is for distinguish between first and successive recursion
simple_location(N) ->
  if %successive recursion case
    N == 1 ->
      % send a message to the server adding a new location
      server ! {add_place, self()}, simple_location(0);
    true ->
      sleep(100),
      % probability of 0,1 % to die for location
      C = rand:uniform(10000),
      case (C < 10) of
        true -> %io:format("C in random dead~p~n", [C]),
          io:format("Death of ~p~n", [self()]),
          % update server and location manager
          server ! {remove_place, self()},
          exit(luogo_morto);
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
  end.


places_manager(L) ->
  process_flag(trap_exit, true),
  link(whereis(server)),
  sleep(?TIMEOUT_LOCATION_MANAGER),
  PID_GETTER = spawn(?MODULE, get_places, [?LIST_LOCATION_LENGTH, L, self()]),
  receive
    {'EXIT', PID, Reason} ->
      case PID == whereis(server) of
        true -> exit(kill);
        false -> io:format("Post mortem LOCATION MANAGER1 ~p,~p, ~n", [PID, Reason]),
          case length(L) > 0 of
            true -> exit(PID_GETTER, kill),
              io:format("Post mortem LOCATION MANAGER2 ~p,~p,~p,~n", [PID, L--[PID], length(L--[PID])]),
              unlink(PID),
              flush(),
              places_manager(L--[PID]);
            false -> exit(PID_GETTER, kill), places_manager(L)
          end
      end;
    {new_places, LR} ->
      io:format("LOCATION MANTAINER UPDATED~p,~p,~n", [LR, length(LR)]),
      [link(PID) || PID <- LR],
      io:format("Link fatto EXIT~n", []),
      places_manager(LR)
  end.

%-----------Visit protocol-----------
visit_manager(L) ->
  process_flag(trap_exit, true),
  %io:format("VISIT MANAGER init ~p~p~n", [L,self()]),
  % Not blocking receive to get places updates (if any)
  receive
    {'EXIT', PLACE_PID, Reason} ->
      io:format("Post mortem in VISIT ~p,~p, ~n", [L, Reason]),
      unlink(PLACE_PID),
      flush(),
      visit_manager(L--[PLACE_PID]);
    {new_places, UL} ->
      io:format("VISIT MANAGER Update~p ~n", [UL]),
      [link(PID) || PID <- UL],
      visit_manager(UL)
  after 0 ->
    ok
  end,
  case length(L) == 0 of
    true ->
      %io:format("VISIT MANAGER TRUE before ~p ~n", [L]),
      receive
        {'EXIT', PLACE_PID2, Reason2} ->
          io:format("Post mortem in VISIT EXIT2 ~p, ~n", [Reason2]),
          unlink(PLACE_PID2),
          flush(),
          visit_manager(L--[PLACE_PID2]);
        {new_places, UL2} ->
          io:format("VISIT MANAGER Update~p ~n", [UL2]),
          [link(PID) || PID <- UL2],
          visit_manager(UL2)
      end;
    false ->
      %io:format("VISIT MANAGER FALSE ~p ~n", [L]),
      sleep(2 + rand:uniform(3)),
      % Ref unused actually
      Ref = make_ref(),
      P = lists:nth(rand:uniform(length(L)), L),
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
%-----------Monitor  protocol-----------

%-----------Main-----------
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


