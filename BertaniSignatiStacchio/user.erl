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
-export([start/0, start_loop/4, places_manager/1, get_places/3, test_manager/1, visit_manager/2]).
-define(TIMEOUT_PLACE_MANAGER, 10000).
-define(TIMEOUT_TEST_MANAGER, 10000).
% number of places a user keeps track
-define(USER_PLACES_NUMBER, 3).


flush_new_places() ->
  receive
    {new_places, _} -> flush_new_places()
  after
    0 -> ok
  end.

sleep(T) -> receive after T -> ok end.

% wait for T seconds for an exit_quarantena message (case user positive)
% in case of user positiveness close earlier the visit and kill the user
sleep_visit(T, PLACE_PID, Ref) ->
  receive {exit_quarantena} -> PLACE_PID ! {end_visit, self(), Ref}, exit(quarantena) after T -> ok end.

%-----------Topology maintenance protocol-----------

get_random_elements_from_list(ACTIVE_PLACES, N, LIST_USER) ->
  if length(LIST_USER) < N ->
    X = rand:uniform(length(ACTIVE_PLACES)),
    % check pre-existence of place in LIST_USER because server sends already delivered places
    case lists:member(lists:nth(X, ACTIVE_PLACES), LIST_USER) of
      true -> get_random_elements_from_list(ACTIVE_PLACES, N, LIST_USER);
      false ->
        get_random_elements_from_list(lists:delete(lists:nth(X, ACTIVE_PLACES), ACTIVE_PLACES),
          N, lists:append(LIST_USER, [lists:nth(X, ACTIVE_PLACES)]))
    end;
    true ->
      LIST_USER
  end.


% retrieve N places and add their PID to LIST_TO_RETURN, answer to PID when completed
get_places(N, LIST_TO_RETURN, PID) ->
  if
    length(LIST_TO_RETURN) < N ->
      global:whereis_name(server) ! {get_places, self()},
      receive
        {places, ACTIVE_PLACES} ->
          io:format("PLACES RECEIVED ~p~n", [ACTIVE_PLACES]),
          case length(ACTIVE_PLACES) >= N of
            true ->
              get_places(N, get_random_elements_from_list(ACTIVE_PLACES, N, LIST_TO_RETURN), PID);
            % not enough active places, die
            false -> exit(normal)
          end
      end;
    true -> PID ! {new_places, LIST_TO_RETURN}, visit_manager ! {new_places, LIST_TO_RETURN}
  end.


% responsible of keeping up to {USER_PLACES_NUMBER} places
places_manager(USER_PLACES_LIST) ->
  process_flag(trap_exit, true), % places_manager needs to know if a place has died to request new places to server
  receive
    {get_places_from_manager, PID3} -> PID3 ! {new_places, USER_PLACES_LIST} %case of visitor resurrection
  after 0 -> ok
  end,
  case length(USER_PLACES_LIST) < ?USER_PLACES_NUMBER of
    true ->
      % spawn a process to asynchronously retrieve up to {USER_PLACES_NUMBER} places
      spawn_monitor(?MODULE, get_places, [?USER_PLACES_NUMBER, USER_PLACES_LIST, self()]);
    false ->
      sleep(?TIMEOUT_PLACE_MANAGER)
  end,
  receive
    {'DOWN', _, process, PID, _} -> % a place has died
      case ((length(USER_PLACES_LIST) > 0) and lists:member(PID, USER_PLACES_LIST)) of
        true ->
          io:format("PLACES MANAGER: place death ~p,~p,~p,~n", [PID, USER_PLACES_LIST--[PID], length(USER_PLACES_LIST--[PID])]),
          flush_new_places(),
          % clear the message queue
          places_manager(USER_PLACES_LIST--[PID]);
        false -> places_manager(USER_PLACES_LIST)
      end;
    {new_places, NEW_PLACES} -> % message received from the spawned process that asked the new places
      io:format("PLACES MANAGER: places updated ~p,~p,~n", [NEW_PLACES, length(NEW_PLACES)]),
      [monitor(process, PID) || PID <- NEW_PLACES], % monitor all the new places
      places_manager(NEW_PLACES);
    {get_places_from_manager, PID} -> PID ! {new_places, USER_PLACES_LIST} %case of visitor resurrection
  end.

%-----------Visit protocol-----------
visit_manager(USER_PLACES, CONTACT_LIST) ->
  process_flag(trap_exit, true),
  % Not blocking receive to get places updates (if any)
  receive
    {'EXIT', PID, Reason} ->
        io:format("VISITOR DEATH OF ~p~p~n", [PID, lists:member(PID, CONTACT_LIST)]),
          case (lists:member(PID, CONTACT_LIST)) and (Reason == quarantena) of
            true -> io:format("~p enters in 'quarantena'~n", [self()]), exit(quarantena);
            false -> ok
          end;
    {'DOWN', _, process, PID, _} ->
      case lists:member(PID, USER_PLACES) of % a user place died
        true -> io:format("VISIT MANAGER: place death ~p,~p, ~n", [PID, USER_PLACES--[PID]]),
          flush_new_places(),
          visit_manager(USER_PLACES--[PID], CONTACT_LIST);
        false -> %if false, the PID could only identify a Place or another user, because of the link made only to the Server and Places.
          case lists:member(PID, CONTACT_LIST) of
            true -> % a person which this user had been in contact has been diagnosed positive
              io:format("CONTACT WITH POSITIVE CASE: contact list: ~p~n", [CONTACT_LIST]),
              io:format("CONTACT WITH POSITIVE CASE: ~p died~n", [PID]),
              io:format("CONTACT WITH POSITIVE CASE: ~p enters in 'quarantena'~n", [self()]), exit(quarantena);
            false -> ok %the PID was referring to a place that was not in the contact list, do nothing
          end
      end;
    {new_places, UL} ->
      io:format("VISIT MANAGER: places updated ~p ~n", [UL]),
      [monitor(process, PID) || PID <- UL],
      visit_manager(UL, CONTACT_LIST);
    {contact, PID_TOUCH} -> io:format("CONTACT UPDATE: contact between ~p and ~p ~n", [self(), PID_TOUCH]),
      link(PID_TOUCH),
      visit_manager(USER_PLACES, CONTACT_LIST ++ [PID_TOUCH])
  after 0 ->
    ok
  end,
  case length(USER_PLACES) == 0 of
    true ->
      receive
        {new_places, UL2} ->
          io:format("VISIT MANAGER: places updated~p ~n", [UL2]),
          [monitor(process, PID) || PID <- UL2],
          visit_manager(UL2, CONTACT_LIST)
      end;
    false ->
      sleep(2 + rand:uniform(3)), % wait for 3-5s
      Ref = make_ref(),
      % choose one random place to visit
      P = lists:nth(rand:uniform(length(USER_PLACES)), USER_PLACES),
      P ! {begin_visit, self(), Ref},
      sleep_visit(4 + rand:uniform(6), P, Ref), % visit duration 5-10s
      P ! {end_visit, self(), Ref},
      visit_manager(USER_PLACES, CONTACT_LIST)
  end.

%-----------Test protocol-----------
% user asks hospital to make illness tests
test_manager(VISITOR_PID) ->
  sleep(?TIMEOUT_TEST_MANAGER),
  case (rand:uniform(4) == 1) of
    true ->
      io:format("TEST covid ~p~n", [global:whereis_name(hospital) ! {test_me, self()}]),
      global:whereis_name(hospital) ! {test_me, self()},
      receive
        positive -> io:format("TEST RES: ~p positive -> 'quarantena'~n", [self()]), VISITOR_PID ! {exit_quarantena},
          exit(quarantena);
        negative -> io:format("TEST RES: ~p negative ~n", [self()]), test_manager(VISITOR_PID)
      end;
    false ->
      test_manager(VISITOR_PID)
  end.


%-----------Monitor  protocol-----------
% if the server dies, kill everything
start_loop(PLACES_MANAGER, VISIT_MANAGER, TEST_MANAGER, SERVER_PID) ->
  io:format("SONO IN START LOOP~p~n", [[PLACES_MANAGER, VISIT_MANAGER, TEST_MANAGER]]),
  process_flag(trap_exit, true),
  [link(P_SP) || P_SP <- [PLACES_MANAGER, VISIT_MANAGER, TEST_MANAGER]],
  receive {'EXIT', SERVER_PID, _} ->
    io:format("SERVER DEATH ~p ~p~n", [SERVER_PID, [PLACES_MANAGER, VISIT_MANAGER, TEST_MANAGER]]),
    [exit(P, kill) || P <- [PLACES_MANAGER, VISIT_MANAGER, TEST_MANAGER]],
    exit(kill);
    {'EXIT', PLACES_MANAGER, _} ->
      % if the place manager dies re-spawn it
      io:format("STO SPAWNANDO PLACES", []),
      [exit(P, kill) || P <- [VISIT_MANAGER,TEST_MANAGER]],
      spawn(?MODULE, start, []);
    {'EXIT', VISIT_MANAGER, Reason} ->
      % if the visit manager dies
      case Reason == quarantena of
        % if the user is positive kill everyone
        true -> [exit(P, kill) || P <- [PLACES_MANAGER, TEST_MANAGER]],
          exit(kill);
        false ->
          io:format("STO SPAWNANDO visitor", []),
          % kill test manager since is parameterized to a died visit manager
          [exit(P, kill) || P <- [PLACES_MANAGER,TEST_MANAGER]],
          spawn(?MODULE, start, [])
      end;
    {'EXIT', TEST_MANAGER, Reason} ->
      % if the test manager dies kill all if the user is ill otherwise respawn it
      case Reason == quarantena of
        true -> [exit(P, kill) || P <- [PLACES_MANAGER, VISIT_MANAGER]],
          exit(kill);
        false -> io:format("STO SPAWNANDO TEST_MANAGER", []),
          [exit(P, kill) || P <- [PLACES_MANAGER,VISIT_MANAGER]],
          spawn(?MODULE, start, [])
      end
  end.


start() ->
  sleep(1000),
  io:format("Hospital ping result: ~p~n", [net_adm:ping(list_to_atom("hospital@" ++ net_adm:localhost()))]),
  PLACES_MANAGER = spawn(?MODULE, places_manager, [[]]),
  register(places_manager, PLACES_MANAGER),
  io:format("PLACES MANAGER SPAWNED~p~n", [PLACES_MANAGER]),
  VISIT_MANAGER = spawn(?MODULE, visit_manager, [[], []]),
  register(visit_manager, VISIT_MANAGER),
  io:format("VISITOR MANAGER SPAWNED~p~n", [VISIT_MANAGER]),
  TEST_MANAGER = spawn(?MODULE, test_manager, [VISIT_MANAGER]),
  register(test_manager, TEST_MANAGER),
  io:format("TEST MANAGER SPAWNED~p~n", [TEST_MANAGER]),
  spawn(?MODULE, start_loop, [PLACES_MANAGER, VISIT_MANAGER, TEST_MANAGER, global:whereis_name(server)]).
