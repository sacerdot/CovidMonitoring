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
-export([test/0, location_manteiner/1, server/1]).

sleep(N) -> receive after N -> ok end.


server(L) ->
  io:format("Lista totale server ~p~n", [L]),
  receive
    {get_places, P} -> io:format("Messaggio ricevuto in server ~n", [])
      , P ! {places, L}
      , server(L)
  end.


generate_N_random_from_list(LR, N, LIST_TO_RETURN) ->
  C = rand:uniform(N),
  io:format("Random ~p,~p,~p,~p~n", [LR, N, LIST_TO_RETURN, C]),
  if
    length(LIST_TO_RETURN) < N ->
      generate_N_random_from_list(lists:delete(lists:nth(C,LR), LR), N , lists:append(LIST_TO_RETURN, [lists:nth(C,LR)]));
    true -> LIST_TO_RETURN
  end.


get_places(L, P) ->
  if
    length(L) < 3 -> io:format("In if loop~p~p~n", [L, length(L)]),
      server ! {get_places, self()},
      receive
        {places, LR} -> io:format("Updatedlist~p~p~n", [LR, length(LR)]),
          P ! {places, generate_N_random_from_list(LR, 3, [])}
      end;
    true -> ok
  end.


location_manteiner(L) ->
  io:format("Lista totale normale~p~p~n", [L, length(L)]),
  sleep(3000),
  get_places(L, self()),
  receive
    {places, LR} -> location_manteiner(LR)
  end.


test() ->
  %mettere link al server
  S = spawn_link(?MODULE, server, [lists:seq(0, 5)]),
  register(server, S), %rendo pubblico associazione nome PID
  %server ! {get_places, self()},
  M = spawn_link(?MODULE, location_manteiner, [[]]),
  io:fwrite("Manteiner spawnata\n").


