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
-export([start/0, places_manager/1, get_places/2, test_manager/1, visit_manager/2]).
-define(TIMEOUT_PM, 10000).
-define(TIMEOUT_TM, 30000).
-define(USER_PLACES_NUMBER, 3). % number of places a user keeps track

flush_new_places() ->
  receive
    {new_places, _} -> flush_new_places()
  after
    0 -> ok
  end.

% wait for T seconds for an exit_quarantena message (case user positive)
% in case of user positiveness close earlier the visit and kill the user
sleep_visit(T, PLACE, Ref) ->
  receive
    {exit_quarantena} ->
      PLACE ! {end_visit, self(), Ref},
      exit(quarantena)
  after
    T -> ok
  end.

%-----------Topology maintenance protocol-----------

get_random_elements(ACTIVE_PLACES, LIST_USER) ->
  case length(LIST_USER) < ?USER_PLACES_NUMBER of
    true ->
      X = rand:uniform(length(ACTIVE_PLACES)),
      % check pre-existence of place in LIST_USER
      case lists:member(lists:nth(X, ACTIVE_PLACES), LIST_USER) of
        true ->
          get_random_elements(ACTIVE_PLACES, LIST_USER);
        false ->
          get_random_elements(
            lists:delete(lists:nth(X, ACTIVE_PLACES), ACTIVE_PLACES),
            lists:append(LIST_USER, [lists:nth(X, ACTIVE_PLACES)]))
      end;
    false -> LIST_USER
  end.


% retrieve N places and add their PID to RET_LIST
% answer to PID when completed
get_places(RET_LIST, PID) ->
  case length(RET_LIST) < ?USER_PLACES_NUMBER of
    true ->
      global:whereis_name(server) ! {get_places, self()},
      receive
        {places, ACTIVE_PLACES} ->
          io:format("POLLING PLACES FROM SERVER ~p~n", [ACTIVE_PLACES]),
          case length(ACTIVE_PLACES) >= ?USER_PLACES_NUMBER of
            true ->
              get_places(get_random_elements(ACTIVE_PLACES, RET_LIST), PID);
            false ->
              exit(normal)  % not enough active places, die
          end
      end;
    false ->
      PID ! {new_places, RET_LIST},
      visit_manager ! {new_places, RET_LIST}
  end.


% responsible of keeping up to {USER_PLACES_NUMBER} places
places_manager(USER_PLACES) ->
  process_flag(trap_exit, true),
  case length(USER_PLACES) < ?USER_PLACES_NUMBER of
    true -> spawn_monitor(?MODULE, get_places, [USER_PLACES, self()]);
    false -> ok
  end,
  receive
    {'DOWN', _, process, PID, _} -> % a place has died
      case ((length(USER_PLACES) > 0) and lists:member(PID, USER_PLACES)) of
        true ->
          io:format("PM: place death ~p,~p,~n", [PID, USER_PLACES--[PID]]),
          flush_new_places(),
          %timer:sleep(?TIMEOUT_PM),
          places_manager(USER_PLACES--[PID]);
        false ->
          places_manager(USER_PLACES)
      end;
    {new_places, NEW_PLACES} ->
      io:format("PM: places updated ~p, ~n", [NEW_PLACES]),
      [monitor(process, PID) || PID <- NEW_PLACES],
      places_manager(NEW_PLACES)
  end.

%-----------Visit protocol-----------
visit_manager(USER_PLACES, CONTACT_LIST) ->
  process_flag(trap_exit, true),
  receive
    {'EXIT', PID, _} ->
      case (lists:member(PID, CONTACT_LIST)) of
        true ->
          io:format("~p enters in 'quarantena' because of ~p~n", [self(),PID]),
          exit(quarantena);
        false -> ok
      end;
    {'DOWN', _, process, PLACE, _} ->
      case lists:member(PLACE, USER_PLACES) of % a user place died
        true ->
          io:format("VM: place death ~p,~p, ~n", [PLACE, USER_PLACES--[PLACE]]),
          flush_new_places(),
          visit_manager(USER_PLACES--[PLACE], CONTACT_LIST);
        false -> ok
      end;
    {new_places, UL} ->
      io:format("VM: places updated ~p ~n", [UL]),
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
      timer:sleep(1000),
      visit_manager(USER_PLACES, CONTACT_LIST);
    false ->
      timer:sleep(2 + rand:uniform(3)),
      Ref = make_ref(),
      % choose one random place to visit
      P = lists:nth(rand:uniform(length(USER_PLACES)), USER_PLACES),
      P ! {begin_visit, self(), Ref},
      sleep_visit(4 + rand:uniform(6), P, Ref), % visit duration 5-10s
      P ! {end_visit, self(), Ref},
      visit_manager(USER_PLACES, CONTACT_LIST)
  end.

%-----------Test protocol-----------
test_manager(VISITOR_PID) ->
  timer:sleep(?TIMEOUT_TM),
  case (rand:uniform(4) == 1) of
    true ->
      io:format("~p is going to make covid test~n", [self()]),
      global:whereis_name(ospedale) ! {test_me, self()},
      receive
        positive ->
          io:format("TEST RESULT: ~p positive -> 'quarantena'~n", [self()]),
          VISITOR_PID ! {exit_quarantena},
          exit(quarantena);
        negative ->
          io:format("TEST RESULT: ~p negative ~n", [self()]),
          test_manager(VISITOR_PID)
      end;
    false ->
      test_manager(VISITOR_PID)
  end.


%-----------Monitor  protocol-----------
start() ->
  timer:sleep(3000),
  io:format("Hospital ping result: ~p~n", [net_adm:ping(list_to_atom("ospedale@" ++ net_adm:localhost()))]),
  SERVER = global:whereis_name(server),
  PM = spawn_link(?MODULE, places_manager, [[]]),
  register(places_manager, PM),
  VM = spawn_link(?MODULE, visit_manager, [[], []]),
  register(visit_manager, VM),
  TM = spawn_link(?MODULE, test_manager, [VM]),
  register(test_manager, TM),
  io:format("Spawned PM ~p & VM ~p & TM ~p~n", [PM, VM, TM]),
  ML = [PM, VM, TM],
  receive
    {'EXIT', KP, REASON} ->
      [unlink(P) || P <- (ML -- [KP])],
      [exit(P, kill) || P <- (ML -- [KP])],
      % if the user is in 'quarantena' or the server dies, kill everything
      case (REASON == quarantena) or (KP == SERVER) of
        true ->
          io:format("The user is dead ~n");
        false ->
          io:format("Restart user ~n"),
          start()
      end
  end.