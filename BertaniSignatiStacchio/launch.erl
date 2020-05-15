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
  os:cmd('werl -s central_server run'),
  os:cmd('werl -s hospital start'),
  %os:cmd('werl -s places init'),
  os:cmd('werl -s user start').
