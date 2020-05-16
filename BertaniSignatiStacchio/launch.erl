%%%-------------------------------------------------------------------
%%% @author Federico Bertani
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 15. mag 2020 11:44
%%%-------------------------------------------------------------------
-module(launch).

-export([launch/0]).

launch () ->
  compile:file(central_server),
  compile:file(hospital),
  %compile:file(place),
  compile:file(user),
  spawn(fun()->os:cmd('werl -s central_server run') end),
  spawn(fun()->os:cmd('werl -s hospital start') end),
  %os:cmd('werl -s places init'),
  user:start().
