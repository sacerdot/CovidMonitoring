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
-export([user/0, location_manager/1, get_places/3, test_manager/0, visit_manager/1, server/1, simple_location/1, simple_hospital/0]).
-define(TIMEOUT_LOCATION_MANAGER, 10000).
-define(TIMEOUT_TEST_MANAGER, 30000).
-define(LIST_LOCATION_LENGTH, 3).



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


simple_location(N) ->
  %io:format("PID~p~n", [self()]),
  if
    N == 1 -> server ! {add_place, self()}, simple_location(0);
    true ->
      sleep(200),
      C = rand:uniform(10000),
      if
        C < 10 -> %io:format("C in random dead~p~n", [C]),
          io:format("Death of ~p~n", [self()]),
          server ! {remove_place, self()},
          location_manager ! {luogo_morto, self()},
          exit(luogo_morto2);
        true -> simple_location(0)
      end
  end.

simple_hospital() ->
  io:format("Hospital PID~p~n", [self()]),
  receive
    {test_me, PID} ->
      P = rand:uniform(4),
      if
        P == 1 -> PID ! {positive};
        true -> PID ! {negative}
      end,
      simple_hospital()
  end.

%----------------------USER----------------------
%-----------Topology maintenance protocol-----------

get_places(N, LIST_TO_RETURN, PID) ->
  if
    length(LIST_TO_RETURN) < N ->
      server ! {get_places, self()},
      receive
        {places, LR} ->
          case length(LR) > N of
            true ->
              C = rand:uniform(length(LR)),
              %io:format("Random ~p,~p,~p,~p~n", [length(LR), N, length(LIST_TO_RETURN), C]), %lists:delete(lists:nth(C, LR), LR),
              case lists:member(lists:nth(C, LR), LIST_TO_RETURN) of
                true -> get_places(N, LIST_TO_RETURN, PID);
                false -> get_places(N, lists:append(LIST_TO_RETURN, [lists:nth(C, LR)]), PID)
              end;
            false -> exit(self(), kill)
          end
      end;
    true -> PID ! {new_places, LIST_TO_RETURN}, visit_manager ! {new_places, LIST_TO_RETURN}
  %TODO: inserire messaggio a visits
  end.


location_manager(L) ->
  io:format("LOCATION MANTAINER~p,~p,~n", [L, length(L)]),
  process_flag(trap_exit, true),
  %link(server),
  sleep(?TIMEOUT_LOCATION_MANAGER),
  PID_GETTER = spawn(?MODULE, get_places, [?LIST_LOCATION_LENGTH, L, self()]),
  receive
    {'EXIT', PLACE_PID, Reason} ->
      io:format("Post mortem EXIT1 ~p, ~n",[Reason]),
        case  length(L) > 0 of
        true -> exit(PID_GETTER, kill),
          io:format("Post mortem EXIT2 ~p,~p,~p,~n", [PLACE_PID, L--[PLACE_PID], length(L--[PLACE_PID])]),
          location_manager(L--[PLACE_PID]);
        false -> exit(PID_GETTER, kill), location_manager(L)
      end;
    {new_places, LR} ->
      [link(PID) || PID <- LR],
      io:format("Link fatto EXIT~n",[]),
      location_manager(LR)
  end.

%-----------Visit protocol-----------
visit_manager(L) ->
  io:format("VISIT MANAGER init ~p~p~n", [L,self()]),
  case length(L) == 0 of
    true ->
      receive
        {new_places, UL} ->io:format("VISIT true  init ~p ~n", [UL]), L=UL
      end;
    false ->   % Not blocking receive to get places updates (if any)
      io:format("VISIT MANAGER Not 0 length ~p ~n", [L]),
      receive
        {new_places, UL} -> L = UL
      after 0 ->
        ok
      end
  end,
    sleep(2 + rand:uniform(3)),
    % Ref unused actually
    Ref = make_ref(),
    P = lists:nth(rand:uniform(length(L)),L),
    P ! {begin_visit, self(), Ref},
    sleep(4 + rand:uniform(6)),
    P ! {end_visit, self(), Ref},
    visit_manager(L).

%-----------Test protocol-----------
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
%TODO: Manage the death of user() when one from M,T dies with a MONITOR.
user() ->
  %mettere link al server
  N = lists:seq(0, 10),
  S = spawn_link(?MODULE, server, [[]]),
  register(server, S), %rendo pubblico associazione nome PID
  [spawn(?MODULE, simple_location, [1]) || X <- N],
  io:format("SERVER SPAWNED~p~n", [S]),
  M = spawn_link(?MODULE, location_manager, [[]]),
  register(location_manager, M),
  io:format("LOCATION MANAGER SPAWNED~p~n", [M]),
  H = spawn_link(?MODULE, simple_hospital, []),
  register(hospital, H),
  io:format("HOSPITAL SPAWNED~p~n", [H]),
  V = spawn_link(?MODULE, visit_manager, [[]]),
  register(visit_manager, V),
  io:format("VISITOR MANAGER SPAWNED~p~n", [V]),
  T = spawn_link(?MODULE, test_manager, []),
  register(test_manager, T),
  io:format("TEST MANAGER SPAWNED~p~n", [T]).


