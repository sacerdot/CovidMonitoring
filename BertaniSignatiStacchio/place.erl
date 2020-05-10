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
-export([init/0]).

%-----------Initialization protocol-----------
init() ->
  link(server),
  server ! {new_place, self()},
  visits([]).

%-----------Visit protocol-----------
visits(USER_LIST) ->
  receive
    {begin_visit, USER_START, _} ->
      % TODO implement 10% probability to close the place when it's visited
      touch(USER_START, USER_LIST),
      visits(USER_LIST ++ [USER_START]);
    {end_visit, USER_END, _} ->
      case lists:member(USER_END, USER_LIST) of
        %TODO current user is not expecting an answer after end visit, so either implement it ot remove it from here
        true ->
          USER_END ! ok,
          visits(USER_LIST -- [USER_END]);
        false ->
          USER_END ! ko,
          visits(USER_LIST)
      end
  end.

%-----------Contact tracing protocol-----------

% for each user in the place create contact with probability of 25%
touch(_, []) -> done;
touch(USER, [H|T]) ->
  V = rand:uniform(4),
  if  V == 1 ->
    H ! {contact, USER},
    USER ! {contact, H}
  end,
  touch(USER, T).
