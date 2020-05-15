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
-export([init/0, visits/1, touch/2]).

%-----------Initialization protocol-----------
init() ->
  link(whereis(server)),
  server ! {new_place, self()},
  spawn_link(?MODULE, visits, [[]]).

%-----------Visit protocol-----------
visits(USER_LIST) ->
  receive
    {'EXIT', PID, _} ->
      io:format("Exit of ~p ~n", [PID]),
      case lists:member({PID, _}, USER_LIST) of
          true ->
            % erase all PID occurrences in user list
            io:format("True visit ~p ~n", [[{P, R} || {P, R} <- USER_LIST, P /= PID]]),
            visits([{P, R} || {P, R} <- USER_LIST, P /= PID]);
          false -> ok
      end;
    {begin_visit, USER_START, REF} ->
      V = rand:uniform(100),
      case (V =< 10) of
        true ->
          exit(normal);
        false ->
          spawn(?MODULE, touch, [USER_START, USER_LIST]),
          visits(USER_LIST ++ [{USER_START, REF}])
      end;
    {end_visit, USER_END, REF} ->
      case lists:member({USER_END, REF}, USER_LIST) of
        true ->
          visits(USER_LIST -- [{USER_END, REF}]);
        false ->
          visits(USER_LIST)
      end
  end.

%-----------Contact tracing protocol-----------

% for each user in the place create contact with probability of 25%
touch(_, []) -> done;
touch(USER, [H|T]) ->
  V = rand:uniform(100),
  if  V =< 25 ->
    H ! {contact, USER},
    USER ! {contact, H}
  end,
  touch(USER, T).
