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
-export([test/0, location_manteiner/1, server/1, simple_location/1, get_places/3]).


sleep(N) -> receive after N -> ok end.


%-----------SERVER AND LOCATION SIMULATED-----------
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
      sleep(50),
      C = rand:uniform(10000),
      if
        C < 10 -> %io:format("C in random dead~p~n", [C]),
          io:format("Death of ~p~n", [self()]),
          server ! {remove_place, self()},
          location_manager ! {luogo_morto, self()},
          exit(normal);
        true -> simple_location(0)
      end
  end.


%-----------USER-----------
get_places(N, LIST_TO_RETURN, PID) ->
  %io:format("BEFORE_C LR ~p,~p,~n", [LR,length(LR)]),
  %io:format("Random ~p,~n", [C]),
  if
    length(LIST_TO_RETURN) < N ->
      server ! {get_places, self()},
      receive
        {places, LR} ->
          if length(LR) >= N - length(LIST_TO_RETURN) ->
            C = rand:uniform(length(LR)),
            %io:format("Random ~p,~p,~p,~p~n", [length(LR), N, length(LIST_TO_RETURN), C]), %lists:delete(lists:nth(C, LR), LR),
            %io:format("LIST TO PID ,~p~n", [list_to_pid(lists:nth(C, LR))]),
            io:format("TEST ~p,~p,~p,~n", [lists:nth(C, LR), LIST_TO_RETURN, lists:member(lists:nth(C, LR), LIST_TO_RETURN)]),
            TEST = lists:member(lists:nth(C, LR), LIST_TO_RETURN),
            if
              TEST -> get_places(N, LIST_TO_RETURN, PID);
              true -> get_places(N, lists:append(LIST_TO_RETURN, [lists:nth(C, LR)]), PID)
            end;
            true -> halt()
          end
      end;
    true -> PID ! {new_places, LIST_TO_RETURN}
  end.

%TODO: INSERT A TRUE MONITOR TO LOCATION PIDS
location_manteiner(L) ->
  %link(server),
  %PID_CHECKER = spawn(?MODULE, location_check, [L,self()]),
  sleep(5000),
  PID_GETTER = spawn(?MODULE, get_places, [3, L, self()]),
  receive
    {luogo_morto, PID_LUOGO} ->
      if length(L) > 0 ->
        exit(PID_GETTER, kill),
        io:format("Post mortem~p,~p,~p,~n", [PID_LUOGO, L--[PID_LUOGO], length(L--[PID_LUOGO])]),
        location_manteiner(L--[PID_LUOGO]);
        true -> exit(PID_GETTER, kill), location_manteiner(L)
      end;
    {new_places, LR} ->%[monitor(self(),PID) || PID <- LR],
      location_manteiner(LR)
  end.



test() ->
  %mettere link al server
  N = lists:seq(0, 10),
  S = spawn_link(?MODULE, server, [[]]),
  register(server, S), %rendo pubblico associazione nome PID
  [spawn(?MODULE, simple_location, [1]) || X <- N],
  M = spawn_link(?MODULE, location_manteiner, [[]]),
  register(location_manager, M),
  %server ! {get_places, self()},
  io:fwrite("Manteiner spawnata\n").


