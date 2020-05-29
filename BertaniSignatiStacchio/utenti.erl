%%%-------------------------------------------------------------------
%%% @author Lorenzo_Stacchio
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 01. mag 2020 11:44
%%%-------------------------------------------------------------------
-module(utenti).
-author("Lorenzo_Stacchio").
%% API
-export([start/0, places_manager/1, get_places/3, test_manager/1, visit_manager/2]).
-define(TIMEOUT_PLACE_MANAGER, 10000).
-define(TIMEOUT_TEST_MANAGER, 30000).
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
          io:format("POLLING PLACES FROM SERVER ~p~n", [ACTIVE_PLACES]),
          case length(ACTIVE_PLACES) >= N of
            true ->
              get_places(N, get_random_elements_from_list(ACTIVE_PLACES, N, LIST_TO_RETURN), PID);
            % not enough active places, die
            false -> exit(normal)
          end
      end;
    true ->
      PID ! {new_places, LIST_TO_RETURN},
      io:format("ecco qua il pid di quel coglione del VM ~p~n", [visit_manager]),
      visit_manager ! {new_places, LIST_TO_RETURN}
  end.


% responsible of keeping up to {USER_PLACES_NUMBER} places
places_manager(USER_PLACES_LIST) ->
  process_flag(trap_exit, true), % places_manager needs to know if a place has died to request new places to server
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
      places_manager(NEW_PLACES)
  end.

%-----------Visit protocol-----------
visit_manager(USER_PLACES, CONTACT_LIST) ->
  process_flag(trap_exit, true),
  % Not blocking receive to get places updates (if any)
  receive
    {'EXIT', PID, _} ->
      case (lists:member(PID, CONTACT_LIST)) of
        true ->
          io:format("~p enters in 'quarantena' because of contact with ~p~n", [self(),PID]),
          exit(quarantena);
        false -> ok
      end;
    {'DOWN', _, process, PID, _} ->
      case lists:member(PID, USER_PLACES) of % a user place died
        true ->
          io:format("VISIT MANAGER: place death ~p,~p, ~n", [PID, USER_PLACES--[PID]]),
          flush_new_places(),
          visit_manager(USER_PLACES--[PID], CONTACT_LIST);
        false -> ok
      end;
    {new_places, UL} ->
      io:format("VISIT MANAGER: places updated ~p ~n", [UL]),
      [monitor(process, PID) || PID <- UL],
      visit_manager(UL, CONTACT_LIST);
    {contact, PID_TOUCH} ->
      io:format("CONTACT BETWEEN ~p & ~p ~n", [self(), PID_TOUCH]),
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
      io:format("~p Is going to make covid test ~p~n", [self(),global:whereis_name(ospedale) ! {test_me, self()}]),
      global:whereis_name(ospedale) ! {test_me, self()},
      receive
        positive -> io:format("TEST RESULT: ~p positive -> 'quarantena'~n", [self()]), VISITOR_PID ! {exit_quarantena},
          exit(quarantena);
        negative -> io:format("TEST RESULT: ~p negative ~n", [self()]), test_manager(VISITOR_PID)
      end;
    false ->
      test_manager(VISITOR_PID)
  end.


%-----------Monitor  protocol-----------
start() ->
  sleep(3000),
  io:format("Hospital ping result: ~p~n", [net_adm:ping(list_to_atom("ospedale@" ++ net_adm:localhost()))]),
  SERVER = global:whereis_name(server),
  PM = spawn(?MODULE, places_manager, [[]]),
  register(places_manager, PM),
  VM = spawn(?MODULE, visit_manager, [[], []]),
  register(visit_manager, VM),
  TM = spawn(?MODULE, test_manager, [VM]),
  register(test_manager, TM),
  io:format("SPAWNED PALCES MANAGER ~p & VISIT MANAGER ~p & TEST MANAGER ~p~n", [PM, VM, TM]),
  ML = [PM, VM, TM],
  [link(P_SP) || P_SP <- ML],
  receive
    {'EXIT', KP, REASON} ->
      [unlink(P) || P <- ML],
      [exit(P, kill) || P <- ML],
      % if the user enters in 'quarantena' or the server is killed, kill everything
      case (REASON == quarantena) or (KP == SERVER) of
        true ->
          io:format("The user is dead ~n");
        false ->
          io:format("Restart user ~n"),
          start()
      end
  end.