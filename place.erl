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

init() ->
  link(server),
  server ! {new_place, self()},
  visits([]).

visits(L) ->
  receive
    {begin_visit, U, REF} ->
      touch(U, L),
      visits(L ++ [U]);
    {end_visit, U, REF} ->
      case lists:member(U,L) of
        true ->
          U ! ok,
          visits(L -- [U]);
        false ->
          U ! ko,
          visits(L)
      end
    end.

touch(_, []) -> done;
touch(U, [H|T]) ->
  V = rand:uniform(4),
  if  V == 1 ->
    H ! {contact, U},
    U ! {contact, H}
  end,
  touch(U, T).
