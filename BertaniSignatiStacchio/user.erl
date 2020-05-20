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
-export([start/0, start_loop/2, places_manager/1, get_places/3, test_manager/0, visit_manager/2]).
-define(TIMEOUT_PLACE_MANAGER, 10000).
-define(TIMEOUT_TEST_MANAGER, 30000).
% number of places a user keep track
-define(USER_PLACES_NUMBER, 3).


flush() ->
  receive
    _ -> flush()
  after
    0 -> ok
  end.

sleep(N) -> receive after N -> ok end.

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
      global:whereis_name(server) ! {get_places, self()},
      receive
        {places, ACTIVE_PLACES} ->
          io:format("PLACES RICEVUTI~p~n", [ACTIVE_PLACES]),
          case length(ACTIVE_PLACES) >= N of
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
  io:format("CALLED_PID_GETTER~p~n", [PID_GETTER]),
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
      %((length(USER_PLACES_LIST) > 0)
      case ((length(USER_PLACES_LIST) > 0) and lists:member(PID, USER_PLACES_LIST)) of
        true -> %exit(PID_GETTER, kill),
          io:format("Post mortem PLACE MANAGER2 ~p,~p,~p,~n", [PID, USER_PLACES_LIST--[PID], length(USER_PLACES_LIST--[PID])]),
          % clear the message queue
          %TODO: INSERIRE FUNZIONE PER ELIMINARE MESSAGGI VECCHI NEW PLACES
          places_manager(USER_PLACES_LIST--[PID]);
        false -> exit(PID_GETTER, kill), places_manager(USER_PLACES_LIST)
      end;
        %end;
    {new_places, NEW_PLACES} -> % message received from the spawned process that asked the new places
      io:format("PLACES MANTAINER UPDATED~p,~p,~n", [NEW_PLACES, length(NEW_PLACES)]),
      [monitor(process,PID) || PID <- NEW_PLACES],% create a link to all this new places
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
          %TODO: INSERIRE FUNZIONE PER ELIMINARE MESSAGGI VECCHI NEW PLACES
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
      io:format("VISIT MANAGER Update RIPETO1~p ~n", [UL]),
      [monitor(process,PID) || PID <- UL],
      visit_manager(UL, CONTACT_LIST);
    {contact, PID_TOUCH} -> link(PID_TOUCH), visit_manager(USER_PLACES, CONTACT_LIST ++ PID_TOUCH)
  after 0 ->
    ok
  end,
  case length(USER_PLACES) == 0 of
    true ->
      receive
        {new_places, UL2} ->
          io:format("VISIT MANAGER Update RIPETO2~p ~n", [UL2]),
          [monitor(process,PID) || PID <- UL2],
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
      io:format("TEST covid ~p~n", [global:whereis_name(hospital) ! {test_me, self()}]),
      global:whereis_name(hospital) ! {test_me, self()};
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
start_loop(SPAWNED_PROCESSES, SERVER_PID) ->
  process_flag(trap_exit, true),
  [link(P_SP) || P_SP <- SPAWNED_PROCESSES],
  receive {'EXIT', SERVER_PID, _} ->
    io:format("MORTO SERVER~p~p~n", [SERVER_PID, SPAWNED_PROCESSES--[SERVER_PID]]),
    sleep(100000),
    [exit(P, kill) || P <- SPAWNED_PROCESSES--[SERVER_PID]],
    exit(kill)
  end.


start() ->
  sleep(2000),
  %mettere link al server
  io:format("ping result: ~p~n", [net_adm:ping('hospital@macerata.homenet.telecomitalia.it')]),
  PLACES_MANAGER = spawn(?MODULE, places_manager, [[]]),
  register(places_manager, PLACES_MANAGER),
  io:format("PLACES MANAGER SPAWNED~p~n", [PLACES_MANAGER]),
  VISIT_MANAGER = spawn(?MODULE, visit_manager, [[], []]),
  register(visit_manager, VISIT_MANAGER),
  io:format("VISITOR MANAGER SPAWNED~p~n", [VISIT_MANAGER]),
  TEST_MANAGER = spawn(?MODULE, test_manager, []),
  register(test_manager, TEST_MANAGER),
  io:format("TEST MANAGER SPAWNED~p~n", [TEST_MANAGER]),
  spawn(?MODULE, start_loop, [[global:whereis_name(server), PLACES_MANAGER, VISIT_MANAGER, TEST_MANAGER], global:whereis_name(server)]).
