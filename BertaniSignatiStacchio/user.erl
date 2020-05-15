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
-export([start/0, start_loop/2, places_manager/1, get_places/3, test_manager/0, server/1, simple_place/1, simple_hospital/0, visit_manager/2]).
-define(TIMEOUT_PLACE_MANAGER, 10000).
-define(TIMEOUT_TEST_MANAGER, 50000).
% number of places a user keep track
-define(USER_PLACES_NUMBER, 3).


flush() ->
  receive
    _ -> flush()
  after
    0 -> ok
  end.

sleep(N) -> receive after N -> ok end.


%-----------SERVER, PLACES,HOSPITAL SIMULATED-----------
server(L) ->
  process_flag(trap_exit, true),
  % link server to all the places in its list
  [link(PID) || PID <- L],
  receive
    {add_place, PL} -> io:format("Lista totale server ~p~pPID,~p~p~n", [self(),L ++ [PL], length(L ++ [PL]), self()]),server(L ++ [PL]);
    {'EXIT', PLACE_PID, Reason} ->
      io:format("Post mortem SERVER ~p, ~n", [Reason]),
      case length(L) > ?USER_PLACES_NUMBER of
        true -> io:format("Rimosso in server ~p ~p~n", [PLACE_PID,L--[PLACE_PID]]), server(L--[PLACE_PID]);
        false -> exit(server_crashed)
      end;
    {get_places, P} ->
      P ! {places, L},
      server(L)
  end.

% the parameter N is for distinguish between first and successive recursion
simple_place(N) ->
  if %successive recursion case
    N == 1 ->
      % send a message to the server adding a new place
      server ! {add_place, self()}, simple_place(0);
    true ->
      sleep(100),
      % probability of 0,1 % to die for place
      C = rand:uniform(10000),
      case (C < 30) of
        true -> %io:format("C in random dead~p~n", [C]),
          io:format("Death of ~p~n", [self()]),
          % update server and place manager
          exit(luogo_morto);
        false -> simple_place(0)
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

get_random_elements_from_list(ACTIVE_PLACES, N, LIST_USER) ->
  if length(LIST_USER) < N ->
    X = rand:uniform(length(ACTIVE_PLACES)),
    % check pre-existance of place in LIST_USER because server sends already delivered places
    case lists:member(lists:nth(X, ACTIVE_PLACES), LIST_USER) of
      true -> get_random_elements_from_list(ACTIVE_PLACES, N, LIST_USER);
      false ->
        get_random_elements_from_list(lists:delete(lists:nth(X, ACTIVE_PLACES), ACTIVE_PLACES),
          N, lists:append(LIST_USER, [lists:nth(X, ACTIVE_PLACES)]))
    end;
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
            true ->
              get_places(N, get_random_elements_from_list(ACTIVE_PLACES, N, LIST_TO_RETURN), PID);
            % not enough active places, die
            false -> exit(normal)
          end
      end;
    true -> PID ! {new_places, LIST_TO_RETURN}, visit_manager ! {new_places, LIST_TO_RETURN}
  end.


% responsible to keeping up to {USER_PLACES_NUMBER} places
places_manager(USER_PLACES_LIST) ->
  process_flag(trap_exit, true), % places_manager need to know if a place has died to request new places to server
  PID_GETTER = spawn_link(?MODULE, get_places, [?USER_PLACES_NUMBER, USER_PLACES_LIST, self()]),
  case length(USER_PLACES_LIST) < ?USER_PLACES_NUMBER of
    true ->
      ok;
    false ->
      exit(PID_GETTER, kill),
      sleep(?TIMEOUT_PLACE_MANAGER)
  end,
  % spawn a process to asynchronously retrieve up to {USER_PLACES_NUMBER} places
  receive
    {'EXIT', PID, _} -> % a place have died
      case ((length(USER_PLACES_LIST) > 0) and lists:member(PID, USER_PLACES_LIST)) of
        true -> %exit(PID_GETTER, kill),
          io:format("Post mortem PLACE MANAGER2 ~p,~p,~p,~n", [PID, USER_PLACES_LIST--[PID], length(USER_PLACES_LIST--[PID])]),
          % clear the message queue
          flush(),
          places_manager(USER_PLACES_LIST--[PID]);
        false -> exit(PID_GETTER, kill), places_manager(USER_PLACES_LIST)
      end;
  %end;
    {new_places, NEW_PLACES} -> % message received from the spawned process that asked the new places
      io:format("PLACES MANTAINER UPDATED~p,~p,~n", [NEW_PLACES, length(NEW_PLACES)]),
      [link(PID) || PID <- NEW_PLACES],% create a link to all this new places
      places_manager(NEW_PLACES)
  end.

%-----------Visit protocol-----------
visit_manager(USER_PLACES, CONTACT_LIST) ->
  process_flag(trap_exit, true),
  % Not blocking receive to get places updates (if any)
  receive
    {'EXIT', PID, Reason} ->
      case lists:member(PID, USER_PLACES) of % a user place died
        true -> io:format("Post mortem in VISIT ~p,~p,~p, ~n", [PID, USER_PLACES--[PID], Reason]),
          flush(),
          visit_manager(USER_PLACES--[PID], CONTACT_LIST);
        false -> %if false, the PID could only identify a Place or another user, because of the link made only to the Server and Places.
          case lists:member(PID, CONTACT_LIST) of
            true -> % a person which this user had been in contact has been diagnosed positive
              io:format("~p:Lista contatti~n", [CONTACT_LIST]), io:format("~p: morto~n", [PID]),
              io:format("~p: Entro in quarantena~n", [self()]), exit(quarantena);
            false -> ok %the PID was referring to a place that was not in the contact list, do nothing
          end
      end;
    {new_places, UL} ->
      io:format("VISIT MANAGER Update~p ~n", [UL]),
      [link(PID) || PID <- UL],
      visit_manager(UL, CONTACT_LIST);
    {contact, PID_TOUCH} -> link(PID_TOUCH), visit_manager(USER_PLACES, CONTACT_LIST ++ PID_TOUCH)
  after 0 ->
    ok
  end,
  case length(USER_PLACES) == 0 of
    true ->
      receive
        {new_places, UL2} ->
          io:format("VISIT MANAGER Update~p ~n", [UL2]),
          [link(PID) || PID <- UL2],
          visit_manager(UL2, CONTACT_LIST)
      end;
    false ->
      %io:format("VISIT MANAGER FALSE ~p ~n", [L]),
      sleep(2 + rand:uniform(3)), % wait for 3-5 as project requirements
      Ref = make_ref(),
      % choose one random place to visit
      P = lists:nth(rand:uniform(length(USER_PLACES)), USER_PLACES),
      %io:format("VISITING MANAGER User:~p,Place:~p ~n", [self(),P]),
      P ! {begin_visit, self(), Ref},
      sleep(4 + rand:uniform(6)), % visit duration as projects requirements
      P ! {end_visit, self(), Ref},
      visit_manager(USER_PLACES, CONTACT_LIST)
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

% if the server dies, kill everything
start_loop(SPAWNED_PROCESSES,SERVER_PID) ->
  process_flag(trap_exit, true),
  [link(P_SP) || P_SP <- SPAWNED_PROCESSES],
  receive {'EXIT', SERVER_PID, _} ->
      io:format("MORTO SERVER~p~p~n", [SERVER_PID,SPAWNED_PROCESSES--[SERVER_PID]]),
              [exit(P,kill) || P <- SPAWNED_PROCESSES--[SERVER_PID]],
              exit(kill)
  end.

start() ->
  %mettere link al server
  N = lists:seq(0, 10),
  SERVER = spawn_link(?MODULE, server, [[]]),
  register(server, SERVER), %rendo pubblico associazione nome PID
  % spawn N places
  [spawn(?MODULE, simple_place, [1]) || _ <- N],
  io:format("SERVER SPAWNED~p~n", [SERVER]),
  PLACES_MANAGER = spawn_link(?MODULE, places_manager, [[]]),
  register(places_manager, PLACES_MANAGER),
  io:format("PLACES MANAGER SPAWNED~p~n", [PLACES_MANAGER]),
  HOSPITAL = spawn_link(?MODULE, simple_hospital, []),
  register(hospital, HOSPITAL),
  io:format("HOSPITAL SPAWNED~p~n", [HOSPITAL]),
  VISIT_MANAGER = spawn_link(?MODULE, visit_manager, [[], []]),
  register(visit_manager, VISIT_MANAGER),
  io:format("VISITOR MANAGER SPAWNED~p~n", [VISIT_MANAGER]),
  TEST_MANAGER = spawn_link(?MODULE, test_manager, []),
  register(test_manager, TEST_MANAGER),
  io:format("TEST MANAGER SPAWNED~p~n", [TEST_MANAGER]),
  spawn(?MODULE, start_loop, [[SERVER,PLACES_MANAGER,HOSPITAL,VISIT_MANAGER,TEST_MANAGER],SERVER]).
