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
-export([user/0, places_manager/1, get_places/3, test_manager/0, server/1, simple_place/1, simple_hospital/0, visit_manager/2]).
-define(TIMEOUT_PLACE_MANAGER, 10000).
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


%-----------SERVER, PLACES,HOSPITAL SIMULATED-----------
server(L) ->
  process_flag(trap_exit, true),
  % link server to all the places in its list
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
      case (C < 10) of
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
    case lists:member(lists:nth(X,ACTIVE_PLACES), LIST_USER) of
      true -> get_random_elements_from_list(ACTIVE_PLACES, N, LIST_USER);
      false ->
        get_random_elements_from_list(lists:delete(lists:nth(X,ACTIVE_PLACES),ACTIVE_PLACES),
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
            false -> exit(self(), kill)
          end
      end;
    true -> PID ! {new_places, LIST_TO_RETURN}, visit_manager ! {new_places, LIST_TO_RETURN}
  end.



% responsibile to keeping up to {USER_PLACES_NUMBER} places
places_manager(USER_PLACES_LIST) ->
  process_flag(trap_exit, true),
  link(whereis(server)),
  PID_GETTER = spawn(?MODULE, get_places, [?USER_PLACES_NUMBER, USER_PLACES_LIST, self()]),
  case length(USER_PLACES_LIST) < ?USER_PLACES_NUMBER of
    true ->
      ok;
    false ->
      exit(PID_GETTER, kill),
      sleep(?TIMEOUT_PLACE_MANAGER)
  end,
  % spawn a process to asyncronisly retrieve up to {USER_PLACES_NUMBER} places
  receive
    {'EXIT', PID, Reason} -> % a place have died
      case PID == whereis(server) of % if the server dies
        true -> exit(kill); % kill the places_manager
        false -> io:format("Post mortem PLACE MANAGER1 ~p,~p, ~n", [PID, Reason]), %otherwise it's a place that died
          % check that the user places list is not empty because it can be in a state where it has requested new places but
          % there are any available and the last one it had, has died
          case length(USER_PLACES_LIST) > 0 of
            true -> %exit(PID_GETTER, kill),
              io:format("Post mortem PLACE MANAGER2 ~p,~p,~p,~n", [PID, USER_PLACES_LIST--[PID], length(USER_PLACES_LIST--[PID])]),
              % clear the message queue
              flush(),
              places_manager(USER_PLACES_LIST--[PID]);
            false -> exit(PID_GETTER, kill), places_manager(USER_PLACES_LIST)
          end
      end;
    {new_places, NEW_PLACES} -> % message received from the spawned process that asked the new places
      io:format("PLACES MANTAINER UPDATED~p,~p,~n", [NEW_PLACES, length(NEW_PLACES)]),
      % create a link to all this new places
      [link(PID) || PID <- NEW_PLACES],
      io:format("Link fatto EXIT~n", []),
      places_manager(NEW_PLACES)
  end.

%-----------Visit protocol-----------
visit_manager(USER_PLACES,CONTACT_LIST) ->
  %TODO SOLVE BLOCKING RECEIVE
  process_flag(trap_exit, true),
  %io:format("VISIT MANAGER init ~p~p~n", [L,self()]),
  % Not blocking receive to get places updates (if any)
  receive
    {'EXIT', PID, Reason} ->
      case Reason of
        luogo_morto -> io:format("Post mortem in VISIT ~p,~p, ~n", [USER_PLACES, Reason]),
          flush(),
          visit_manager(USER_PLACES--[PID],CONTACT_LIST);
        quarantena -> io:format("~p:Lista contatti~n", [CONTACT_LIST]), io:format("~p: morto~n", [PID]),
          io:format("~p: Entro in quarantena~n", [self()]), exit(quarantena)
      end;
    {new_places, UL} ->
      io:format("VISIT MANAGER Update~p ~n", [UL]),
      [link(PID) || PID <- UL],
      visit_manager(UL,CONTACT_LIST);
    {contact, PID_TOUCH} -> link(PID_TOUCH), visit_manager(USER_PLACES,CONTACT_LIST++PID_TOUCH)
  after 0 ->
    ok
  end,
  case length(USER_PLACES) == 0 of
    true ->
      %io:format("VISIT MANAGER TRUE before ~p ~n", [L]),
      receive
        {'EXIT', PID2, Reason2} ->
          case Reason2 of
            luogo_morto -> io:format("Post mortem in VISIT ~p,~p, ~n", [USER_PLACES, Reason2]),
              flush(),
              visit_manager(USER_PLACES--[PID2],CONTACT_LIST);
            quarantena -> io:format("~p:Lista contatti~n", [CONTACT_LIST]), io:format("~p: morto~n", [PID2]),
              io:format("~p: Entro in quarantena~n", [self()]), exit(quarantena)
          end;
        {new_places, UL2} ->
          io:format("VISIT MANAGER Update~p ~n", [UL2]),
          [link(PID) || PID <- UL2],
          visit_manager(UL2,CONTACT_LIST);
        {contact, PID2} -> link(PID2), visit_manager(USER_PLACES,CONTACT_LIST++PID2)
      end;
    false ->
      %io:format("VISIT MANAGER FALSE ~p ~n", [L]),
      sleep(2 + rand:uniform(3)),
      % Ref unused actually
      Ref = make_ref(),
      P = lists:nth(rand:uniform(length(USER_PLACES)), USER_PLACES),
      P ! {begin_visit, self(), Ref},
      sleep(4 + rand:uniform(6)),
      P ! {end_visit, self(), Ref},
      visit_manager(USER_PLACES,CONTACT_LIST)
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
  % spawn N places
  [spawn(?MODULE, simple_place, [1]) || _ <- N],
  io:format("SERVER SPAWNED~p~n", [SERVER]),
  PLACES_MANAGER = spawn_link(?MODULE, places_manager, [[]]),
  register(places_manager, PLACES_MANAGER),
  io:format("PLACES MANAGER SPAWNED~p~n", [PLACES_MANAGER]),
  HOSPITAL = spawn_link(?MODULE, simple_hospital, []),
  register(hospital, HOSPITAL),
  io:format("HOSPITAL SPAWNED~p~n", [HOSPITAL]),
  VISIT_MANAGER = spawn_link(?MODULE, visit_manager, [[],[]]),
  register(visit_manager, VISIT_MANAGER),
  io:format("VISITOR MANAGER SPAWNED~p~n", [VISIT_MANAGER]),
  TEST_MANAGER = spawn_link(?MODULE, test_manager, []),
  register(test_manager, TEST_MANAGER),
  io:format("TEST MANAGER SPAWNED~p~n", [TEST_MANAGER]).
