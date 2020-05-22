%%%-------------------------------------------------------------------
%%% @author Teresa Signati
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 01. May 2020 11:44
%%%-------------------------------------------------------------------
-module(place).
-author("TeresaSignati").

%% API
-export([start/0, visits/1, touch/2]).
-define(DEATH_PROB, 600).

sleep(N) -> receive after N -> ok end.

%-----------Initialization protocol-----------
start() ->
  sleep(2000),
  monitor(process, global:whereis_name(server)),
  global:whereis_name(server) ! {new_place, self()},
  io:format("OPENED PLACE~p~n", [self()]),
  visits([]).

%----------------Visit protocol---------------
visits(USER_LIST) ->
  receive
    {'DOWN', _, process, PID, _} -> % it's a user but for safety we will check it
      case global:whereis_name(server) == PID of true ->
        exit(kill)
      end;
    {begin_visit, USER_START, REF} ->
      io:format("BEGIN VISIT ~p~n", [USER_START]),
      V = rand:uniform(?DEATH_PROB),
      case (V =< 1) of
        true ->
          io:format("CLOSED PLACE ~p~n", [self()]),
          exit(normal);
        false ->
          spawn(?MODULE, touch, [USER_START, USER_LIST]),
          visits(USER_LIST ++ [{USER_START, REF}])
      end;
    {end_visit, USER_END, REF} ->
      io:format("END VISIT ~p ~n", [USER_END]),
      case lists:member({USER_END, REF}, USER_LIST) of
        true ->
          visits(USER_LIST -- [{USER_END, REF}]);
        false ->
          visits(USER_LIST)
      end
  end.

%-----------Contact tracing protocol----------

% for each user in the place create contact with probability of 25%
touch(_, []) -> done;
touch(USER, [H | T]) ->
  {P, _} = H,
  case rand:uniform(100) =< 25 of
    true ->
      io:format("CONTACTS: contact between ~p and ~p~n", [USER, P]),
      P ! {contact, USER},
      USER ! {contact, P};
    false ->
      io:format("CONTACTS: no contact between ~p and ~p~n", [USER, P])
  end,
  touch(USER, T).
