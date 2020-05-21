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
  io:format("SONO VISIT~p~n", [self()]),
  visits([]).

%-----------Visit protocol-----------
visits(USER_LIST) ->
  receive
    {'EXIT', PID, _} ->
      case lists:member(PID, USER_LIST) of
        true ->
          io:format("Exit of ~p ~n", [PID]),
          visits([{P, R} || {P, R} <- USER_LIST, P /= PID])
      end;
    {'DOWN', _, process, PID, _} -> % it's a user but for safety we will check it
      case global:whereis_name(server) == PID of true ->
        exit(kill)
      end;
    {begin_visit, USER_START, REF} ->
      io:format("BEGIN VISIT~p ~n", [USER_START]),
      V = rand:uniform(?DEATH_PROB),
      case (V =< 1) of
        true ->
          io:format("SONO MORTO VISIT~p~n", [self()]),
          exit(normal);
        false ->
          link(USER_START),
          spawn(?MODULE, touch, [USER_START, USER_LIST]),
          visits(USER_LIST ++ [{USER_START, REF}])
      end;
    {end_visit, USER_END, REF} ->
      case lists:member({USER_END, REF}, USER_LIST) of
        true ->
          unlink(USER_END),
          visits(USER_LIST -- [{USER_END, REF}]);
        false ->
          visits(USER_LIST)
      end
  end.

%-----------Contact tracing protocol-----------

% for each user in the place create contact with probability of 25%
touch(_, []) -> done;
touch(USER, [H | T]) ->
  io:format("SONO IN TOUCH~p~p~p~n", [USER, H, T]),
  case rand:uniform(100) =< 25 of
    true -> {P, _} = H,
      P ! {contact, USER},
      USER ! {contact, P};
    false -> ok
  end,
  touch(USER, T).
