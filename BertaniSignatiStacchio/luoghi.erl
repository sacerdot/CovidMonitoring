%%%-------------------------------------------------------------------
%%% @author Teresa Signati
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 01. May 2020 11:44
%%%-------------------------------------------------------------------
-module(luoghi).
-author("TeresaSignati").

%% API
-export([start/0, visits/1, touch/2]).
-define(DEATH_PROB, 10).

%-----------Initialization protocol-----------
start() ->
  timer:sleep(2000),
  link(global:whereis_name(server)),
  global:whereis_name(server) ! {new_place, self()},
  io:format("OPENED PLACE~p~n", [self()]),
  visits([]).

%----------------Visit protocol---------------
visits(USER_LIST) ->
  receive
    {begin_visit, USER, REF} ->
      io:format("BEGIN VISIT ~p~n", [USER]),
      case (rand:uniform(?DEATH_PROB) =< 1) of
        true ->
          io:format("CLOSED PLACE ~p~n", [self()]),
          exit(normal);
        false ->
          spawn(?MODULE, touch, [USER, USER_LIST]),
          visits(USER_LIST ++ [{USER, REF}])
      end;
    {end_visit, USER, REF} ->
      io:format("END VISIT ~p ~n", [USER]),
      case lists:member({USER, REF}, USER_LIST) of
        true ->
          visits(USER_LIST -- [{USER, REF}]);
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
      P ! {contact, USER},
      USER ! {contact, P};
    false ->ok
  end,
  touch(USER, T).
